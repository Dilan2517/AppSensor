import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  runApp(const BrujulaApp());
}

class BrujulaApp extends StatelessWidget {
  const BrujulaApp({super.key});

  // Construye la configuración principal de la aplicación.
  // Aquí se define el tema, el fondo y la pantalla inicial.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Brújula',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090B10),
        useMaterial3: true,
      ),
      home: const CompassPage(),
    );
  }
}

class CompassPage extends StatefulWidget {
  const CompassPage({super.key});

  // Crea el estado de la pantalla principal de la brújula.
  @override
  State<CompassPage> createState() => _CompassPageState();
}

class _CompassPageState extends State<CompassPage>
    with SingleTickerProviderStateMixin {

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;

  double _ax = 0;
  double _ay = 0;
  double _az = 0;

  double _mx = 0;
  double _my = 0;
  double _mz = 0;

  double _targetHeading = 0;
  double _animatedHeading = 0;

  bool _hasSensorData = false;

  late AnimationController _animationController;
  Timer? _uiTimer;

  // Inicializa los elementos necesarios para que la brújula
  // pueda comenzar a funcionar.
  // También inicia los sensores, la animación y el temporizador.
  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_updateAnimation);

    _animationController.repeat();

    _startSensors();

    _uiTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) {
        if (!mounted) return;

        setState(() {});
      },
    );
  }

  // Inicia la lectura del acelerómetro y del magnetómetro.
  // Cada vez que llegan nuevos datos se vuelve a calcular
  // el rumbo de la brújula.
  void _startSensors() {
    _accelerometerSubscription =
        accelerometerEventStream(
      samplingPeriod: const Duration(
        milliseconds: 20,
      ),
    ).listen((event) {
      _ax = event.x;
      _ay = event.y;
      _az = event.z;

      _calculateHeading();
    });

    _magnetometerSubscription =
        magnetometerEventStream(
      samplingPeriod: const Duration(
        milliseconds: 20,
      ),
    ).listen((event) {
      _mx = event.x;
      _my = event.y;
      _mz = event.z;

      _calculateHeading();
    });
  }

  // Calcula el rumbo utilizando los datos del acelerómetro
  // y del magnetómetro.
  // Primero obtiene la gravedad, después elimina su componente
  // del campo magnético y finalmente calcula el ángulo.
  void _calculateHeading() {
    final gravityMagnitude = sqrt(
      _ax * _ax +
          _ay * _ay +
          _az * _az,
    );

    if (gravityMagnitude < 0.1) {
      return;
    }

    final gx = _ax / gravityMagnitude;
    final gy = _ay / gravityMagnitude;
    final gz = _az / gravityMagnitude;

    final magneticDotGravity =
        _mx * gx +
        _my * gy +
        _mz * gz;

    final hx =
        _mx - magneticDotGravity * gx;

    final hy =
        _my - magneticDotGravity * gy;

    final hz =
        _mz - magneticDotGravity * gz;

    final horizontalMagnitude = sqrt(
      hx * hx +
          hy * hy +
          hz * hz,
    );

    if (horizontalMagnitude < 0.1) {
      return;
    }

    var degrees =
        atan2(hy, hx) * 180 / pi;

    if (degrees < 0) {
      degrees += 360;
    }

    degrees = (degrees + 90) % 360;

    final difference = _shortestAngleDifference(
      degrees,
      _targetHeading,
    );

    _targetHeading =
        (_targetHeading + difference * 0.15 + 360) %
            360;

    _hasSensorData = true;
  }

  // Actualiza progresivamente la posición de la brújula
  // para que el movimiento se vea más suave.
  void _updateAnimation() {
    final difference = _shortestAngleDifference(
      _targetHeading,
      _animatedHeading,
    );

    _animatedHeading =
        (_animatedHeading + difference * 0.12 + 360) %
            360;
  }

  // Calcula la diferencia más corta entre dos ángulos.
  // Esto evita que la brújula haga una vuelta completa
  // cuando pasa de valores cercanos a 360 hacia 0 grados.
  double _shortestAngleDifference(
    double target,
    double current,
  ) {
    var difference = target - current;

    while (difference > 180) {
      difference -= 360;
    }

    while (difference < -180) {
      difference += 360;
    }

    return difference;
  }

  // Convierte el valor de los grados en una dirección
  // de la brújula, como Norte, Sur, Este u Oeste.
  String _getDirection(double degrees) {
    if (degrees >= 337.5 || degrees < 22.5) {
      return 'NORTE';
    }

    if (degrees < 67.5) {
      return 'NORESTE';
    }

    if (degrees < 112.5) {
      return 'ESTE';
    }

    if (degrees < 157.5) {
      return 'SURESTE';
    }

    if (degrees < 202.5) {
      return 'SUR';
    }

    if (degrees < 247.5) {
      return 'SUROESTE';
    }

    if (degrees < 292.5) {
      return 'OESTE';
    }

    return 'NOROESTE';
  }

  // Libera los recursos utilizados por la pantalla
  // cuando deja de estar activa.
  // Cancela los sensores, la animación y el temporizador.
  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _animationController.dispose();
    _uiTimer?.cancel();

    super.dispose();
  }

  // Construye la interfaz principal de la brújula.
  // Aquí se muestran el rumbo, la dirección, la rosa de los vientos,
  // la aguja, las marcas y el estado de los sensores.
  @override
  Widget build(BuildContext context) {
    final direction = _getDirection(_animatedHeading);
    final degrees = _animatedHeading.round();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),

            const Text(
              'BRÚJULA',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
                color: Color(0xFF8E96A3),
              ),
            ),

            const SizedBox(height: 6),

            Text(
              direction,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 25),

            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.maxWidth;

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: size * 0.94,
                            height: size * 0.94,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF252A34),
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),

                          CustomPaint(
                            size: Size(size, size),
                            painter: CompassTicksPainter(),
                          ),

                          Transform.rotate(
                            angle:
                                -_animatedHeading * pi / 180,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                _cardinal(
                                  'N',
                                  Alignment.topCenter,
                                  const Color(0xFFFF4D5A),
                                  _animatedHeading,
                                ),

                                _cardinal(
                                  'S',
                                  Alignment.bottomCenter,
                                  Colors.white,
                                  _animatedHeading,
                                ),

                                _cardinal(
                                  'E',
                                  Alignment.centerRight,
                                  Colors.white,
                                  _animatedHeading,
                                ),

                                _cardinal(
                                  'O',
                                  Alignment.centerLeft,
                                  Colors.white,
                                  _animatedHeading,
                                ),

                                _diagonal(
                                  'NO',
                                  Alignment.topLeft,
                                  _animatedHeading,
                                ),

                                _diagonal(
                                  'NE',
                                  Alignment.topRight,
                                  _animatedHeading,
                                ),

                                _diagonal(
                                  'SO',
                                  Alignment.bottomLeft,
                                  _animatedHeading,
                                ),

                                _diagonal(
                                  'SE',
                                  Alignment.bottomRight,
                                  _animatedHeading,
                                ),
                              ],
                            ),
                          ),

                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF11151D),
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                          ),

                          Positioned(
                            top: size * 0.09,
                            child: Container(
                              width: 3,
                              height: size * 0.16,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF4D5A),
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                            ),
                          ),

                          Positioned(
                            top: 0,
                            child: CustomPaint(
                              size: const Size(18, 18),
                              painter: TrianglePainter(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),

            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF11151D),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFF242A35),
                ),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RUMBO',
                        style: TextStyle(
                          color: Color(0xFF737B89),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        '$degrees°',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),

                  Container(
                    width: 1,
                    height: 45,
                    color: const Color(0xFF2A303B),
                  ),

                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'DIRECCIÓN',
                        style: TextStyle(
                          color: Color(0xFF737B89),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        direction,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _hasSensorData
                        ? const Color(0xFF49D17D)
                        : const Color(0xFFFFC857),
                  ),
                ),

                const SizedBox(width: 8),

                Text(
                  _hasSensorData
                      ? 'Sensores activos'
                      : 'Inicializando sensores...',
                  style: const TextStyle(
                    color: Color(0xFF737B89),
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  // Crea las letras correspondientes a las direcciones principales
  // de la brújula: Norte, Sur, Este y Oeste.
  Widget _cardinal(
    String text,
    Alignment alignment,
    Color color,
    double rotation,
  ) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Transform.rotate(
          angle: rotation * pi / 180,
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  // Crea las direcciones diagonales de la brújula:
  // Noreste, Noroeste, Sureste y Suroeste.
  Widget _diagonal(
    String text,
    Alignment alignment,
    double rotation,
  ) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(43),
        child: Transform.rotate(
          angle: rotation * pi / 180,
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF737B89),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}


// Clase encargada de dibujar las marcas alrededor
// de la brújula.
class CompassTicksPainter extends CustomPainter {

  // Dibuja las marcas de los grados alrededor del círculo.
  // Las marcas se generan cada 5 grados y tienen diferentes
  // tamaños dependiendo de su posición.
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius = size.width * 0.45;

    final paint = Paint()
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 360; i += 5) {
      final angle = (i - 90) * pi / 180;

      final isMajor = i % 45 == 0;
      final isMedium = i % 15 == 0;

      double innerRadius;

      if (isMajor) {
        innerRadius = radius - 20;
        paint.strokeWidth = 2;
        paint.color = const Color(0xFF9AA2B1);
      } else if (isMedium) {
        innerRadius = radius - 14;
        paint.strokeWidth = 1.5;
        paint.color = const Color(0xFF5F6775);
      } else {
        innerRadius = radius - 8;
        paint.strokeWidth = 1;
        paint.color = const Color(0xFF3B424E);
      }

      final start = Offset(
        center.dx + cos(angle) * innerRadius,
        center.dy + sin(angle) * innerRadius,
      );

      final end = Offset(
        center.dx + cos(angle) * radius,
        center.dy + sin(angle) * radius,
      );

      canvas.drawLine(
        start,
        end,
        paint,
      );
    }
  }

  // Indica que las marcas no necesitan volver a dibujarse
  // porque su apariencia no cambia durante la aplicación.
  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}


// Clase encargada de dibujar el indicador triangular
// que aparece en la parte superior de la brújula.
class TrianglePainter extends CustomPainter {

  // Dibuja el triángulo utilizando Canvas y Path.
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = const Color(0xFFFF4D5A)
      ..style = PaintingStyle.fill;

    final path = Path();

    path.moveTo(
      size.width / 2,
      0,
    );

    path.lineTo(
      size.width,
      size.height,
    );

    path.lineTo(
      0,
      size.height,
    );

    path.close();

    canvas.drawPath(
      path,
      paint,
    );
  }

  // El indicador no cambia durante la ejecución,
  // por lo que no necesita volver a dibujarse.
  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}
import 'package:flutter/material.dart';

import 'package:flutter_spinkit/flutter_spinkit.dart';

class LoadingIndicator extends StatelessWidget {

  const LoadingIndicator({super.key});

  @override

  Widget build(BuildContext context) {

    return const Padding(

      padding: EdgeInsets.all(8.0),

      child: SpinKitThreeBounce(color: Colors.indigo, size: 24),

    );

  }

}




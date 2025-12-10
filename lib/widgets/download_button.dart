import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

class FileDownloadButton extends StatelessWidget {

  final String label;

  final String? url;

  const FileDownloadButton({super.key, required this.label, required this.url});

  @override

  Widget build(BuildContext context) {

    final enabled = url != null && url!.isNotEmpty;

    return ListTile(

      title: Text(label),

      subtitle: Text(enabled ? url! : 'Not generated'),

      trailing: ElevatedButton(

        onPressed: enabled ? () => launchUrl(Uri.parse(url!)) : null,

        child: const Text('Download'),

      ),

    );

  }

}




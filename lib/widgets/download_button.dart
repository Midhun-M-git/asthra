import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class FileDownloadButton extends StatelessWidget {
  final String label;
  final String? url;

  const FileDownloadButton({super.key, required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    final enabled = url != null && url!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Colors.white10)),
        tileColor: Colors.white.withOpacity(0.05),
        leading: const Icon(Icons.file_present, color: Colors.blueAccent),
        title: Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(
          enabled ? url! : 'Not generated',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: ElevatedButton(
          onPressed: enabled ? () {
             String fullUrl = url!;
             if (!fullUrl.startsWith('http')) {
               fullUrl = 'http://localhost:8000$fullUrl'; // TODO: Use ApiClient.baseUrl
             }
             launchUrl(Uri.parse(fullUrl));
          } : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.withOpacity(0.2),
          ),
          child: const Icon(Icons.download),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre una URL de GitLab en el navegador.
///
/// En una app de solo lectura esta es la válvula de escape: todo lo que aquí
/// no se puede hacer (comentar, aprobar, cerrar) se hace allí.
Future<void> openInGitlab(BuildContext context, String? url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);

  if (url == null || url.isEmpty) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('Este elemento no tiene enlace en GitLab.')),
    );
    return;
  }

  final uri = Uri.tryParse(url);
  var opened = false;
  if (uri != null) {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  if (!opened) {
    messenger?.showSnackBar(SnackBar(content: Text('No se pudo abrir $url')));
  }
}

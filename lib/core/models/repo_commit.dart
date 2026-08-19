/// Commit real de un repositorio.
///
/// Llega de `/projects/:id/repository/compare?from=&to=`, que es la única vía
/// para obtener los commits concretos de un push: los eventos solo traen el
/// título del último. Se pide al abrir el detalle de un push, nunca al pintar
/// la lista.
class RepoCommit {
  const RepoCommit({
    required this.id,
    required this.shortId,
    required this.title,
    required this.authorName,
    this.message,
    this.authorEmail,
    this.createdAt,
    this.webUrl,
  });

  final String id;
  final String shortId;
  final String title;
  final String authorName;
  final String? message;
  final String? authorEmail;
  final DateTime? createdAt;
  final String? webUrl;

  factory RepoCommit.fromJson(Map<String, dynamic> json) => RepoCommit(
    id: json['id'] as String? ?? '',
    shortId: json['short_id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    authorName: json['author_name'] as String? ?? '',
    message: json['message'] as String?,
    authorEmail: json['author_email'] as String?,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    webUrl: json['web_url'] as String?,
  );
}

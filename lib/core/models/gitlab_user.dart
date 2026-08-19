/// Usuario de GitLab, tal y como aparece en `/user` y embebido como `author`
/// en eventos y merge requests. Se queda con lo que la UI necesita: el payload
/// completo de `/user` trae más de 40 campos que no usamos.
class GitlabUser {
  const GitlabUser({
    required this.id,
    required this.username,
    required this.name,
    this.avatarUrl,
    this.webUrl,
  });

  final int id;
  final String username;
  final String name;
  final String? avatarUrl;
  final String? webUrl;

  factory GitlabUser.fromJson(Map<String, dynamic> json) => GitlabUser(
    id: json['id'] as int,
    username: json['username'] as String? ?? '',
    name: json['name'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
    webUrl: json['web_url'] as String?,
  );
}

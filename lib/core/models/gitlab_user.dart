/// Usuario de GitLab, de `/user` o embebido como `author`. Solo lo que usa
/// la UI: el payload completo trae 40+ campos.
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

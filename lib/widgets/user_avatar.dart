import 'package:flutter/material.dart';

import '../services/session.dart';

/// The signed-in person's profile picture, or their first initial when there is
/// none. It follows [Session.user], so a photo changed on My Profile shows up
/// in the menu and the top bar at once.
class UserAvatar extends StatefulWidget {
  const UserAvatar({
    super.key,
    required this.radius,
    required this.backgroundColor,
    required this.initialStyle,
  });

  final double radius;
  final Color backgroundColor;
  final TextStyle initialStyle;

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  // Decoding a data: photo is not free: keep the result until the photo changes.
  String? _url;
  ImageProvider? _provider;

  ImageProvider? _providerFor(String? url) {
    if (url == null || url.isEmpty) {
      _url = null;
      return _provider = null;
    }
    if (url == _url) return _provider;
    _url = url;
    try {
      _provider = url.startsWith('data:')
          ? MemoryImage(UriData.parse(url).contentAsBytes())
          : NetworkImage(url);
    } catch (_) {
      _provider = null;
    }
    return _provider;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUser?>(
      valueListenable: Session.user,
      builder: (context, user, _) {
        final name = user?.name.trim() ?? '';
        final initial = name.isEmpty ? 'E' : name[0].toUpperCase();
        final image = _providerFor(user?.avatarUrl);
        return CircleAvatar(
          radius: widget.radius,
          backgroundColor: widget.backgroundColor,
          // If the picture cannot load, the initial underneath shows instead.
          foregroundImage: image,
          onForegroundImageError: image == null ? null : (_, _) {},
          child: Text(initial, style: widget.initialStyle),
        );
      },
    );
  }
}

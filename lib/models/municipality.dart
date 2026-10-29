// One of the towns of Guimaras (Buenavista, Jordan, etc).
// iconAsset is reserved for a real icon image later (e.g. 'assets/icons/jordan.png');
// until those image files exist, screens fall back to a Material icon.
class Municipality {
  final String id;
  final String name;
  final String iconAsset;

  const Municipality({
    required this.id,
    required this.name,
    required this.iconAsset,
  });
}

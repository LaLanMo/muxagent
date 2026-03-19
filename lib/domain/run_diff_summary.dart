class FileDiffStat {
  final String path;
  final int additions;
  final int deletions;
  final String oldText;
  final String newText;

  const FileDiffStat({
    required this.path,
    required this.additions,
    required this.deletions,
    required this.oldText,
    required this.newText,
  });
}

class RunDiffSummary {
  final List<FileDiffStat> files;
  final int totalAdditions;
  final int totalDeletions;

  const RunDiffSummary({
    required this.files,
    required this.totalAdditions,
    required this.totalDeletions,
  });

  int get fileCount => files.length;
}

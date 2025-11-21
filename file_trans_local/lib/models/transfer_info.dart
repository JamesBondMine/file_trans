/// 传输信息模型
class TransferInfo {
  final String fileName;
  final int fileSize;
  final double progress;
  final TransferStatus status;
  final String? errorMessage;

  TransferInfo({
    required this.fileName,
    required this.fileSize,
    this.progress = 0.0,
    this.status = TransferStatus.idle,
    this.errorMessage,
  });

  TransferInfo copyWith({
    String? fileName,
    int? fileSize,
    double? progress,
    TransferStatus? status,
    String? errorMessage,
  }) {
    return TransferInfo(
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(2)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  int get progressPercentage => (progress * 100).toInt();
}

enum TransferStatus {
  idle,
  preparing,
  transferring,
  completed,
  failed,
}


sealed class UiEffect {}

final class ShowToast extends UiEffect {
  final String message;
  ShowToast(this.message);
}

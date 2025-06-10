extension OptionalListExtension<T> on List<T> {
  T? at(int index) {
    if (index >= 0 && index < length) {
      return this[index];
    }
    return null;
  }
}

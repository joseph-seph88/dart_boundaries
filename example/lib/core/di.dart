// Core DI layer — accessible from all layers.
class Locator {
  static final _instances = <Type, Object>{};

  static void register<T extends Object>(T instance) {
    _instances[T] = instance;
  }

  static T get<T extends Object>() => _instances[T] as T;
}

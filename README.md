# polly_flutter

**Flutter-first resilience widgets built on top of [polly_dart](https://pub.dev/packages/polly_dart).**

`polly_flutter` brings enterprise-grade resilience patterns — retry, circuit breaker, rate limiting, caching, timeout, and more — directly into your widget tree. Instead of wiring up resilience logic manually in your services or BLoCs, you declare it declaratively on the widget itself.

---

## Table of Contents

- [Why polly\_flutter?](#why-polly_flutter)
- [Features](#features)
- [Architecture](#architecture)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
  - [ResilienceSnapshot](#resiliencesnapshot)
  - [ResiliencePipeline](#resiliencepipeline)
  - [ResilienceTheme](#resiliencetheme)
  - [DefaultPipelines](#defaultpipelines)
- [Widget Reference](#widget-reference)
  - [ResilientFutureBuilder](#resilientfuturebuilder)
  - [ResilientStreamBuilder](#resilientstreambuilder)
  - [ResilientCachedBuilder](#resilientcachedbuilder)
  - [ResilientNetworkImage](#resilientnetworkimage)
  - [ResilientButton](#resilientbutton)
  - [ResilientForm](#resilientform)
  - [ResilientRefreshIndicator](#resilientrefreshindicator)
  - [ResilientListView](#resilientlistview)
  - [ResilientInfiniteScroll](#resilientinfinitescroll)
  - [ResilientConnectivityWrapper](#resilientconnectivitywrapper)
  - [ResilientContainer](#resilientcontainer)
- [Advanced Usage](#advanced-usage)
  - [Composing Custom Pipelines](#composing-custom-pipelines)
  - [Combining Widgets](#combining-widgets)
  - [Offline-First Patterns](#offline-first-patterns)
- [Testing](#testing)
- [Contributing](#contributing)

---

## Why polly_flutter?

Modern mobile apps fail constantly — flaky networks, rate-limited APIs, temporary backend outages, slow image CDNs, and accidental double-taps. The standard Flutter toolkit gives you `FutureBuilder` and `StreamBuilder`, but neither knows what to do when things go wrong.

`polly_flutter` wraps every async operation in a configurable **resilience pipeline** that handles failure automatically:

| Problem | Solution |
|---|---|
| Network request fails | Retry with exponential backoff |
| Backend is down | Circuit breaker stops hammering it |
| User double-taps a button | Debounce / rate limiter prevents duplicate calls |
| Image CDN is slow | Fallback URL or widget with retries |
| App goes offline mid-stream | Auto-reconnect with backoff |
| Paginated list fails mid-scroll | Per-page error recovery with retry |
| API response is expensive | In-memory TTL cache |

---

## Features

- **`ResilientFutureBuilder`** — drop-in `FutureBuilder` replacement with retry, timeout, and refresh
- **`ResilientStreamBuilder`** — auto-reconnecting stream subscriptions
- **`ResilientCachedBuilder`** — future builder with a built-in TTL memory cache
- **`ResilientNetworkImage`** — cached image loading with retry, circuit breaker, and URL fallback
- **`ResilientButton`** — async button with debounce, loading state, and retry
- **`ResilientForm`** — form submission through a resilience pipeline
- **`ResilientRefreshIndicator`** — pull-to-refresh with rate limiting
- **`ResilientListView`** — full-list loader with retry and pull-to-refresh
- **`ResilientInfiniteScroll`** — paginated infinite scroll with per-page error recovery
- **`ResilientConnectivityWrapper`** — online/offline switcher using `connectivity_plus`
- **`ResilientContainer`** — general-purpose async initializer container
- **`ResilienceTheme`** — theming support for all widget states
- **`DefaultPipelines`** — pre-built pipelines for the most common scenarios

---

## Architecture

```
polly_flutter
│
├── Widgets                   ← StatefulWidgets that manage resilience lifecycle
│   └── Each widget holds a ResiliencePipeline built from polly_dart strategies
│
├── ResilienceSnapshot<T>     ← Immutable state value: idle / loading / success / error / retrying
│
├── ResilienceTheme           ← InheritedWidget providing visual theming
│
└── DefaultPipelines          ← Factory helpers for pre-built pipelines
        │
        └── polly_dart        ← Core strategy engine (retry, circuit breaker, cache, …)
```

Every resilient widget accepts an optional `pipelineBuilder` callback:

```dart
pipelineBuilder: (builder) => builder
    .addRetry(RetryStrategyOptions(maxRetryAttempts: 3))
    .addTimeout(Duration(seconds: 10))
    .addCircuitBreaker(),
```

When omitted, sensible defaults are applied automatically.

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  polly_flutter: ^0.0.1
```

Then run:

```sh
flutter pub get
```

### Platform support

| Android | iOS | Web | macOS | Windows | Linux |
|:---:|:---:|:---:|:---:|:---:|:---:|
| ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## Quick Start

```dart
import 'package:polly_flutter/polly_flutter.dart';

// Wrap your app with ResilienceTheme (optional, provides consistent styling)
void main() {
  runApp(
    ResilienceTheme(
      data: const ResilienceThemeData(),
      child: MyApp(),
    ),
  );
}

// Use a resilient widget anywhere in your tree
class UserProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ResilientFutureBuilder<User>(
      futureFactory: () => UserRepository.getUser(userId),
      builder: (context, snapshot) {
        if (snapshot.isLoading) return const CircularProgressIndicator();
        if (snapshot.hasError)  return ErrorView(error: snapshot.error);
        return UserCard(user: snapshot.data!);
      },
    );
  }
}
```

That's it. The widget automatically retries up to 3 times with exponential backoff if the request fails, transitions through `loading → retrying → success/error` states, and cleans up after itself on dispose.

---

## Core Concepts

### ResilienceSnapshot

Every widget exposes its state through a `ResilienceSnapshot<T>`, which is an immutable value object carrying:

| Property | Type | Description |
|---|---|---|
| `status` | `ResilienceStatus` | Current lifecycle state |
| `data` | `T?` | Result value when successful |
| `error` | `Object?` | The exception when failed |
| `stackTrace` | `StackTrace?` | Stack trace accompanying the error |
| `attemptNumber` | `int` | Current retry attempt (1-based) |

**Status values:**

| Status | Meaning |
|---|---|
| `idle` | No operation started |
| `loading` | Operation in flight |
| `success` | Completed successfully |
| `error` | Failed after all retries |
| `retrying` | Failed once, retrying |
| `rateLimited` | Blocked by rate limiter |
| `circuitOpen` | Circuit breaker is open |

**Convenience getters:** `isLoading`, `isSuccess`, `hasError`, `isRetrying`, `hasData`, `isIdle`, `isRateLimited`, `isCircuitOpen`

**`.when()` extension** — pattern-match on status without if/else chains:

```dart
snapshot.when(
  idle:       ()          => const SizedBox.shrink(),
  loading:    ()          => const CircularProgressIndicator(),
  success:    (data)      => MyWidget(data: data),
  error:      (e, st)     => ErrorView(error: e),
  retrying:   (attempt)   => Text('Retrying… attempt $attempt'),
)
```

**`.maybeWhen()` extension** — shorthand when you only care about success:

```dart
snapshot.maybeWhen(
  data:    (user) => UserTile(user: user),
  orElse:  ()     => const CircularProgressIndicator(),
)
```

---

### ResiliencePipeline

Widgets accept an optional `pipelineBuilder` parameter of type:

```dart
ResiliencePipelineBuilder Function(ResiliencePipelineBuilder)?
```

You receive a fresh builder and return the configured one. Available strategies from `polly_dart`:

```dart
pipelineBuilder: (b) => b
  .addRetry(RetryStrategyOptions(
    maxRetryAttempts: 3,
    delay: Duration(seconds: 1),
    backoffType: DelayBackoffType.exponential,
    useJitter: true,
  ))
  .addTimeout(Duration(seconds: 10))
  .addCircuitBreaker(CircuitBreakerStrategyOptions(
    failureRatio: 0.5,
    minimumThroughput: 5,
    breakDuration: Duration(seconds: 30),
  ))
  .addRateLimiter(RateLimiterStrategyOptions.tokenBucket(
    permitLimit: 10,
    window: Duration(seconds: 1),
  ))
  .addMemoryCache<MyType>(ttl: Duration(minutes: 5)),
```

**Strategy execution order matters.** Strategies are applied outermost-first (the first one added is the outermost wrapper). A typical recommended order is:

```
cache → retry → circuit breaker → timeout
```

---

### ResilienceTheme

`ResilienceTheme` is an `InheritedWidget` you place near the root of your app. It provides default colours and text styles to all resilient widgets below it.

```dart
ResilienceTheme(
  data: ResilienceThemeData(
    loadingColor: Colors.indigo,
    errorColor:   Colors.red,
    successColor: Colors.green,
    offlineColor: Colors.orange,
    errorTextStyle:  TextStyle(color: Colors.red, fontSize: 14),
    statusTextStyle: TextStyle(color: Colors.grey, fontSize: 12),
  ),
  child: MyApp(),
)
```

Access it anywhere:

```dart
final theme = ResilienceTheme.of(context);
```

---

### DefaultPipelines

Pre-built pipelines for the most common scenarios — use them directly or as a starting point:

```dart
// 3 retries, exponential backoff with jitter
DefaultPipelines.standardRetry()

// Retry + circuit breaker — good for image loading
DefaultPipelines.networkImage()

// 10s timeout + 1 retry — good for user-triggered actions
DefaultPipelines.userAction()

// Memory cache (5 min TTL) + retry — good for expensive fetches
DefaultPipelines.cachedFetch<MyType>(ttl: Duration(minutes: 10))

// Retry + 15s timeout — good for pagination
DefaultPipelines.pagination()
```

---

## Widget Reference

---

### ResilientFutureBuilder

A drop-in replacement for Flutter's `FutureBuilder` that automatically retries on failure, manages loading/error/retrying states, and optionally polls on an interval.

#### Constructor

```dart
ResilientFutureBuilder<T>({
  required Future<T> Function() futureFactory,
  required Widget Function(BuildContext, ResilienceSnapshot<T>) builder,
  ResiliencePipelineBuilder Function(ResiliencePipelineBuilder)? pipelineBuilder,
  Widget Function(BuildContext)? loadingBuilder,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  Widget Function(BuildContext, int attempt)? retryBuilder,
  Duration? refreshInterval,
  bool autoExecute = true,
  void Function(T)? onSuccess,
  void Function(Object, StackTrace?)? onError,
})
```

#### Parameters

| Parameter | Description |
|---|---|
| `futureFactory` | Called on each attempt to produce a fresh `Future<T>` |
| `builder` | Main builder — receives the current `ResilienceSnapshot<T>` |
| `pipelineBuilder` | Customize the resilience pipeline |
| `loadingBuilder` | Override the default loading UI |
| `errorBuilder` | Override the default error UI |
| `retryBuilder` | Widget shown during a retry attempt; receives the attempt number |
| `refreshInterval` | If set, re-executes the factory on this interval (polling) |
| `autoExecute` | Whether to start immediately on first build (default: `true`) |
| `onSuccess` | Callback invoked with the result after a successful execution |
| `onError` | Callback invoked with the error after all retries are exhausted |

#### Usage

**Basic:**

```dart
ResilientFutureBuilder<String>(
  futureFactory: () => api.getMessage(),
  builder: (context, snapshot) {
    if (snapshot.isLoading) return const CircularProgressIndicator();
    if (snapshot.hasError)  return Text('Error: ${snapshot.error}');
    return Text(snapshot.data!);
  },
)
```

**With custom loading and error widgets:**

```dart
ResilientFutureBuilder<List<Product>>(
  futureFactory: () => api.getProducts(),
  loadingBuilder: (_) => const ProductSkeletonList(),
  errorBuilder:  (_, error, _) => ErrorBanner(message: error.toString()),
  retryBuilder:  (_, attempt) => Text('Retrying ($attempt of 3)…'),
  builder: (context, snapshot) => ProductGrid(products: snapshot.data ?? []),
)
```

**With polling (auto-refresh every 30 seconds):**

```dart
ResilientFutureBuilder<StockPrice>(
  futureFactory: () => api.getPrice('AAPL'),
  refreshInterval: const Duration(seconds: 30),
  builder: (context, snapshot) => PriceTicker(price: snapshot.data),
)
```

**Custom pipeline — cache + circuit breaker:**

```dart
ResilientFutureBuilder<WeatherData>(
  futureFactory: () => weatherApi.getForecast(city),
  pipelineBuilder: (b) => b
      .addMemoryCache<WeatherData>(ttl: const Duration(minutes: 10))
      .addRetry(RetryStrategyOptions(maxRetryAttempts: 2))
      .addCircuitBreaker(),
  builder: (context, snapshot) => WeatherCard(data: snapshot.data),
)
```

---

### ResilientStreamBuilder

Subscribes to a `Stream` and automatically reconnects with exponential backoff when the stream emits an error or closes unexpectedly.

#### Constructor

```dart
ResilientStreamBuilder<T>({
  required Stream<T> Function() streamFactory,
  required Widget Function(BuildContext, ResilienceSnapshot<T>) builder,
  ResiliencePipelineBuilder Function(ResiliencePipelineBuilder)? pipelineBuilder,
  Widget Function(BuildContext)? loadingBuilder,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  int maxReconnectAttempts = 5,
  Duration reconnectDelay = const Duration(seconds: 2),
})
```

#### Parameters

| Parameter | Description |
|---|---|
| `streamFactory` | Called on each (re)connection attempt to produce a fresh stream |
| `builder` | Receives every new snapshot as the stream emits |
| `maxReconnectAttempts` | Max reconnect attempts; `0` = unlimited |
| `reconnectDelay` | Base delay before reconnect (doubles on each attempt) |

#### Usage

**WebSocket / real-time feed:**

```dart
ResilientStreamBuilder<ChatMessage>(
  streamFactory: () => chatService.messageStream(roomId),
  builder: (context, snapshot) {
    if (snapshot.isLoading || snapshot.isRetrying) {
      return ConnectionStatusBar(
        message: snapshot.isRetrying
            ? 'Reconnecting… (attempt ${snapshot.attemptNumber})'
            : 'Connecting…',
      );
    }
    if (snapshot.hasError) return DisconnectedBanner();
    return MessageBubble(message: snapshot.data!);
  },
)
```

**Unlimited reconnects with custom delay:**

```dart
ResilientStreamBuilder<SensorReading>(
  streamFactory: () => iotDevice.readings(),
  maxReconnectAttempts: 0,  // never give up
  reconnectDelay: const Duration(seconds: 5),
  builder: (context, snapshot) => SensorDisplay(reading: snapshot.data),
)
```

---

### ResilientCachedBuilder

A `ResilientFutureBuilder` variant that adds an automatic in-memory cache layer with a configurable TTL. Subsequent builds within the TTL window return cached data instantly without hitting the network.

#### Constructor

```dart
ResilientCachedBuilder<T>({
  required String cacheKey,
  required Future<T> Function() futureFactory,
  required Widget Function(BuildContext, ResilienceSnapshot<T>) builder,
  Duration cacheTtl = const Duration(minutes: 5),
  Widget Function(BuildContext)? loadingBuilder,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  void Function(T)? onSuccess,
  void Function(Object, StackTrace?)? onError,
})
```

#### Parameters

| Parameter | Description |
|---|---|
| `cacheKey` | Unique string key for this cached value |
| `cacheTtl` | How long to keep the cached result before re-fetching |

The widget exposes a `refresh()` method via a `GlobalKey` if you need to invalidate the cache programmatically.

#### Usage

```dart
ResilientCachedBuilder<UserProfile>(
  cacheKey: 'profile:$userId',
  cacheTtl: const Duration(minutes: 10),
  futureFactory: () => userApi.getProfile(userId),
  builder: (context, snapshot) {
    if (snapshot.isLoading) return const ProfileSkeleton();
    return ProfileCard(profile: snapshot.data!);
  },
)
```

---

### ResilientNetworkImage

A drop-in network image widget that applies retry and circuit breaker before falling back to an alternative URL or a custom fallback widget. Internally backed by `cached_network_image`.

#### Constructor

```dart
ResilientNetworkImage({
  required String imageUrl,
  String? fallbackImageUrl,
  Widget? fallbackWidget,
  ResiliencePipelineBuilder Function(ResiliencePipelineBuilder)? pipelineBuilder,
  ProgressIndicatorBuilder? progressIndicatorBuilder,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  BoxFit? fit,
  double? width,
  double? height,
})
```

#### Parameters

| Parameter | Description |
|---|---|
| `imageUrl` | Primary image URL |
| `fallbackImageUrl` | Secondary URL attempted if the primary fails |
| `fallbackWidget` | Widget displayed when all sources fail (e.g. `Icon(Icons.broken_image)`) |
| `progressIndicatorBuilder` | Custom loading progress widget (receives `DownloadProgress`) |

#### Usage

**Basic with fallback:**

```dart
ResilientNetworkImage(
  imageUrl: user.avatarUrl,
  fallbackWidget: CircleAvatar(
    backgroundColor: Colors.grey.shade300,
    child: Text(user.initials),
  ),
  width: 56,
  height: 56,
  fit: BoxFit.cover,
)
```

**With fallback URL and progress indicator:**

```dart
ResilientNetworkImage(
  imageUrl: 'https://cdn.example.com/hero.jpg',
  fallbackImageUrl: 'https://backup-cdn.example.com/hero.jpg',
  progressIndicatorBuilder: (context, url, progress) => LinearProgressIndicator(
    value: progress.progress,
  ),
  width: double.infinity,
  height: 300,
  fit: BoxFit.cover,
)
```

**Aggressive circuit breaker for a flaky CDN:**

```dart
ResilientNetworkImage(
  imageUrl: product.imageUrl,
  fallbackWidget: const Icon(Icons.image_not_supported, size: 48),
  pipelineBuilder: (b) => b
      .addRetry(RetryStrategyOptions(maxRetryAttempts: 1))
      .addCircuitBreaker(CircuitBreakerStrategyOptions(
        failureRatio: 0.3,
        minimumThroughput: 3,
        breakDuration: Duration(minutes: 1),
      )),
  width: 200,
  height: 200,
)
```

---

### ResilientButton

An `ElevatedButton` wrapper that executes an async action through a resilience pipeline. Prevents double-taps via debouncing, shows a loading indicator while the action is in flight, and calls back on success or failure.

#### Constructor

```dart
ResilientButton({
  VoidCallback? onPressed,
  Future<void> Function()? onAsyncPressed,
  ResiliencePipelineBuilder Function(ResiliencePipelineBuilder)? pipelineBuilder,
  Duration debounceTime = const Duration(milliseconds: 300),
  required Widget child,
  Widget? loadingChild,
  ButtonStyle? style,
  VoidCallback? onSuccess,
  void Function(Object, StackTrace?)? onError,
})
```

Provide either `onPressed` (synchronous, bypasses pipeline) or `onAsyncPressed` (async, goes through pipeline).

#### Parameters

| Parameter | Description |
|---|---|
| `onAsyncPressed` | Async callback wrapped by the resilience pipeline |
| `debounceTime` | Minimum time between taps; additional taps within this window are ignored |
| `loadingChild` | Widget shown inside the button while the action is running |
| `onSuccess` | Callback invoked after a successful action |
| `onError` | Callback invoked after the action fails (after retries) |

#### Usage

**Basic async button:**

```dart
ResilientButton(
  onAsyncPressed: () => orderService.placeOrder(cart),
  onSuccess: () => Navigator.pushNamed(context, '/confirmation'),
  onError: (e, _) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(e.toString()))),
  child: const Text('Place Order'),
)
```

**Custom loading state:**

```dart
ResilientButton(
  onAsyncPressed: () => authService.login(email, password),
  loadingChild: const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 16, height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      ),
      SizedBox(width: 8),
      Text('Signing in…'),
    ],
  ),
  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
  child: const Text('Sign In'),
)
```

**With aggressive debounce and single retry:**

```dart
ResilientButton(
  onAsyncPressed: () => likeService.toggleLike(postId),
  debounceTime: const Duration(milliseconds: 500),
  pipelineBuilder: (b) => b
      .addRetry(RetryStrategyOptions(maxRetryAttempts: 1))
      .addTimeout(const Duration(seconds: 5)),
  child: const Icon(Icons.favorite_border),
)
```

---

### ResilientForm

A `Form` wrapper that submits through a resilience pipeline, managing validation, loading state, and error display in a single cohesive API.

#### Constructor

```dart
ResilientForm({
  required Widget Function(BuildContext, ResilientFormState) builder,
  Future<void> Function(Map<String, dynamic> data)? onSubmit,
  ResiliencePipelineBuilder Function(ResiliencePipelineBuilder)? pipelineBuilder,
  GlobalKey<FormState>? formKey,
})
```

The `builder` receives a `ResilientFormState` object:

| Property / Method | Description |
|---|---|
| `isLoading` | `true` while the submit action is running |
| `error` | The exception from the last failed submission |
| `submit()` | Validates, saves, and submits the form |
| `setValue(key, value)` | Store a field value from `onSaved` |

#### Usage

```dart
ResilientForm(
  onSubmit: (data) => authApi.register(
    email: data['email'],
    password: data['password'],
  ),
  pipelineBuilder: (b) => b
      .addRetry(RetryStrategyOptions(maxRetryAttempts: 2))
      .addTimeout(const Duration(seconds: 15)),
  builder: (context, formState) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextFormField(
        decoration: const InputDecoration(labelText: 'Email'),
        keyboardType: TextInputType.emailAddress,
        validator: (v) => v!.contains('@') ? null : 'Invalid email',
        onSaved: (v) => formState.setValue('email', v),
      ),
      const SizedBox(height: 12),
      TextFormField(
        decoration: const InputDecoration(labelText: 'Password'),
        obscureText: true,
        validator: (v) => v!.length >= 8 ? null : 'Min 8 characters',
        onSaved: (v) => formState.setValue('password', v),
      ),
      const SizedBox(height: 8),
      if (formState.error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            formState.error.toString(),
            style: const TextStyle(color: Colors.red),
          ),
        ),
      const SizedBox(height: 8),
      ElevatedButton(
        onPressed: formState.isLoading ? null : formState.submit,
        child: formState.isLoading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Create Account'),
      ),
    ],
  ),
)
```

---

### ResilientRefreshIndicator

A `RefreshIndicator` that wraps the refresh callback in a resilience pipeline and applies a rate limit to prevent users from spamming the refresh gesture.

#### Constructor

```dart
ResilientRefreshIndicator({
  required Future<void> Function() onRefresh,
  required Widget child,
  Duration rateLimitInterval = const Duration(seconds: 3),
  ResiliencePipelineBuilder Function(ResiliencePipelineBuilder)? pipelineBuilder,
  void Function(Object, StackTrace?)? onError,
})
```

#### Usage

```dart
ResilientRefreshIndicator(
  onRefresh: () => controller.reload(),
  rateLimitInterval: const Duration(seconds: 5),
  onError: (e, _) => showErrorSnackBar(context, e),
  child: ListView.builder(
    itemCount: posts.length,
    itemBuilder: (ctx, i) => PostCard(post: posts[i]),
  ),
)
```

---

### ResilientListView

A widget that loads a full list through a resilience pipeline and renders it in a `ListView`. Supports pull-to-refresh, custom empty states, loading skeletons, and error recovery with a retry button.

#### Constructor

```dart
ResilientListView<T>({
  required Future<List<T>> Function() dataLoader,
  required Widget Function(BuildContext, T) itemBuilder,
  ResiliencePipelineBuilder Function(ResiliencePipelineBuilder)? pipelineBuilder,
  Widget Function(BuildContext)? loadingBuilder,
  Widget Function(BuildContext, Object, StackTrace?, VoidCallback retry)? errorBuilder,
  Widget? emptyWidget,
  bool enableRefresh = true,
})
```

#### Parameters

| Parameter | Description |
|---|---|
| `dataLoader` | Fetches the full list |
| `itemBuilder` | Builds each list item |
| `errorBuilder` | Receives `(context, error, stackTrace, retry)` — call `retry()` to re-fetch |
| `emptyWidget` | Shown when the loaded list is empty |
| `enableRefresh` | Wraps the list in a `RefreshIndicator` (default: `true`) |

#### Usage

**Simple list with skeleton loader:**

```dart
ResilientListView<Notification>(
  dataLoader: () => notificationApi.getAll(),
  loadingBuilder: (_) => const NotificationSkeletonList(),
  emptyWidget: const EmptyInbox(),
  errorBuilder: (ctx, error, _, retry) => ErrorCard(
    message: 'Could not load notifications',
    onRetry: retry,
  ),
  itemBuilder: (ctx, notification) => NotificationTile(
    notification: notification,
  ),
)
```

---

### ResilientInfiniteScroll

A `ListView.builder` with resilient pagination. Automatically fetches the next page when the user scrolls near the bottom, with per-page error recovery so a single failed page doesn't kill the whole list.

#### Constructor

```dart
ResilientInfiniteScroll<T>({
  required Future<List<T>> Function(int page) fetchPage,
  required Widget Function(BuildContext, T) itemBuilder,
  ResiliencePipelineBuilder Function(ResiliencePipelineBuilder)? pipelineBuilder,
  int pageSize = 20,
  double loadMoreThreshold = 200.0,
  Widget? loadingIndicator,
  Widget Function(BuildContext, Object, VoidCallback retry)? errorBuilder,
  Widget? emptyWidget,
})
```

#### Parameters

| Parameter | Description |
|---|---|
| `fetchPage` | Called with the 1-based page number; returns items for that page |
| `pageSize` | Expected items per page; used to detect end-of-list |
| `loadMoreThreshold` | Pixels from bottom before triggering next page fetch |
| `loadingIndicator` | Footer widget while loading the next page |
| `errorBuilder` | Footer widget when a page fails; receives `retry` callback |

End-of-list detection: when a page returns fewer items than `pageSize`, pagination stops.

#### Usage

**Product catalog with custom page error:**

```dart
ResilientInfiniteScroll<Product>(
  fetchPage: (page) => productApi.getProducts(page: page, size: 20),
  pageSize: 20,
  emptyWidget: const EmptyCatalog(),
  loadingIndicator: const Padding(
    padding: EdgeInsets.all(16),
    child: Center(child: CircularProgressIndicator()),
  ),
  errorBuilder: (ctx, error, retry) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Failed to load more'),
        const SizedBox(width: 8),
        TextButton(onPressed: retry, child: const Text('Retry')),
      ],
    ),
  ),
  itemBuilder: (ctx, product) => ProductCard(product: product),
)
```

---

### ResilientConnectivityWrapper

Monitors network connectivity using `connectivity_plus` and switches between `onlineChild` and `offlineChild` in real time.

#### Constructor

```dart
ResilientConnectivityWrapper({
  required Widget onlineChild,
  required Widget offlineChild,
  Widget Function(BuildContext, List<ConnectivityResult>)? statusBuilder,
  void Function(bool isOnline)? onConnectivityChanged,
})
```

#### Parameters

| Parameter | Description |
|---|---|
| `onlineChild` | Shown when at least one connection is available |
| `offlineChild` | Shown when there is no connection |
| `statusBuilder` | Full override — receives the raw `List<ConnectivityResult>` |
| `onConnectivityChanged` | Called with `true` (online) or `false` (offline) on every change |

#### Usage

**Offline banner:**

```dart
ResilientConnectivityWrapper(
  onlineChild: MainContent(),
  offlineChild: Column(
    children: [
      const OfflineBanner(),
      Expanded(child: CachedContent()),
    ],
  ),
  onConnectivityChanged: (isOnline) {
    if (isOnline) controller.reload(); // auto-refresh when back online
  },
)
```

**Custom status builder for detailed connectivity info:**

```dart
ResilientConnectivityWrapper(
  onlineChild: const SizedBox.shrink(), // not used when statusBuilder is set
  offlineChild: const SizedBox.shrink(),
  statusBuilder: (context, results) {
    final isWifi = results.contains(ConnectivityResult.wifi);
    final isMobile = results.contains(ConnectivityResult.mobile);
    return Column(
      children: [
        if (!isWifi && !isMobile) const OfflineBanner(),
        if (isMobile && !isWifi) const SlowConnectionBanner(),
        Expanded(child: MainContent()),
      ],
    );
  },
)
```

---

### ResilientContainer

A general-purpose widget that runs an async initializer (e.g. database migration, feature flag fetch, SDK init) through a resilience pipeline before rendering its `child`. Shows a loading or error state during initialization.

#### Constructor

```dart
ResilientContainer({
  required Widget child,
  Future<void> Function()? initializer,
  Widget? loadingChild,
  Widget Function(BuildContext, Object, StackTrace?, VoidCallback retry)? errorBuilder,
  ResiliencePipelineBuilder Function(ResiliencePipelineBuilder)? pipelineBuilder,
})
```

#### Usage

**Guarding a screen behind async initialization:**

```dart
ResilientContainer(
  initializer: () => FeatureFlagService.init(),
  loadingChild: const SplashScreen(),
  errorBuilder: (ctx, error, _, retry) => InitFailedScreen(
    error: error,
    onRetry: retry,
  ),
  child: HomeScreen(),
)
```

---

## Advanced Usage

### Composing Custom Pipelines

```dart
// A pipeline for a critical payment endpoint
final paymentPipeline = ResiliencePipelineBuilder()
    .addTimeout(const Duration(seconds: 30))
    .addRetry(RetryStrategyOptions(
      maxRetryAttempts: 2,
      delay: const Duration(seconds: 2),
      backoffType: DelayBackoffType.exponential,
      // Only retry on network errors, not on 4xx responses
      shouldHandle: PredicateBuilder<void>()
          .handle<SocketException>()
          .handle<TimeoutException>()
          .build(),
    ))
    .addCircuitBreaker(CircuitBreakerStrategyOptions(
      failureRatio: 0.3,
      minimumThroughput: 3,
      breakDuration: const Duration(minutes: 1),
    ))
    .build();

ResilientButton(
  pipelineBuilder: (_) => ResiliencePipelineBuilder()
      .addTimeout(const Duration(seconds: 30))
      .addRetry(/* ... */),
  onAsyncPressed: () => paymentService.charge(amount),
  child: const Text('Pay Now'),
)
```

### Combining Widgets

Nest widgets to build compound resilience:

```dart
// Connectivity-aware screen with a resilient list inside
ResilientConnectivityWrapper(
  offlineChild: const OfflineScreen(),
  onlineChild: ResilientRefreshIndicator(
    onRefresh: controller.reload,
    child: ResilientInfiniteScroll<Post>(
      fetchPage: (page) => api.getPosts(page: page),
      itemBuilder: (ctx, post) => ResilientNetworkImage(
        imageUrl: post.thumbnailUrl,
        width: 80,
        height: 80,
      ),
    ),
  ),
)
```

### Offline-First Patterns

Combine `ResilientCachedBuilder` with `ResilientConnectivityWrapper` for a true offline-first experience:

```dart
ResilientConnectivityWrapper(
  onConnectivityChanged: (online) {
    if (online) feedController.refresh();
  },
  offlineChild: ResilientCachedBuilder<List<Article>>(
    cacheKey: 'feed',
    cacheTtl: const Duration(hours: 24), // serve stale cache when offline
    futureFactory: () => Future.error('offline'), // always fail → serve cache
    builder: (ctx, snap) => ArticleList(articles: snap.data ?? []),
  ),
  onlineChild: ResilientCachedBuilder<List<Article>>(
    cacheKey: 'feed',
    cacheTtl: const Duration(minutes: 5),
    futureFactory: () => articleApi.getFeed(),
    builder: (ctx, snap) => ArticleList(articles: snap.data ?? []),
  ),
)
```

---

## Testing

All resilient widgets are standard `StatefulWidget`s and test exactly like any Flutter widget using `flutter_test`.

**Pattern — inject a pipeline with no strategies for fast, deterministic tests:**

```dart
ResilientFutureBuilder<String>(
  futureFactory: () async => 'hello',
  pipelineBuilder: (b) => b, // empty pipeline — no retry delays
  builder: (ctx, snap) => Text(snap.data ?? ''),
)
```

**Pattern — test retry behaviour by counting factory calls:**

```dart
testWidgets('retries 3 times before showing error', (tester) async {
  var calls = 0;
  await tester.pumpWidget(_wrap(
    ResilientFutureBuilder<String>(
      futureFactory: () async {
        calls++;
        throw Exception('fail');
      },
      pipelineBuilder: (b) => b.addRetry(
        RetryStrategyOptions(
          maxRetryAttempts: 3,
          delay: Duration.zero, // no delay in tests
        ),
      ),
      builder: (ctx, snap) => snap.hasError
          ? const Text('error')
          : const CircularProgressIndicator(),
    ),
  ));

  await tester.pumpAndSettle();
  expect(find.text('error'), findsOneWidget);
  expect(calls, 4); // 1 initial + 3 retries
});
```

---

## Contributing

Contributions are very welcome. Please open an issue first to discuss significant changes.

1. Fork and clone the repo
2. Run `flutter test` to confirm the baseline
3. Make your changes and add/update tests
4. Run `flutter analyze` and fix any warnings
5. Open a pull request with a clear description

---

## License

MIT — see [LICENSE](LICENSE).

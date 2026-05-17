import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import '../utils/app_logger.dart';
import '../utils/l10n_utils.dart';
import 'api_endpoints.dart';

/// Dio 网络请求客户端（单例模式）
class DioClient {
  static final DioClient instance = DioClient._internal();

  late final Dio dio;

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        // 基础 URL（根据实际 API 修改）
        baseUrl: ApiEndpoints.baseUrl,
        // 连接超时时间
        connectTimeout: const Duration(seconds: 10),
        // 接收超时时间
        receiveTimeout: const Duration(seconds: 10),
        // 发送超时时间
        sendTimeout: const Duration(seconds: 10),
        // 默认请求头
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // 添加拦截器
    _setupInterceptors();
  }

  /// 配置拦截器
  void _setupInterceptors() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // 注入 JWT token（已登录时自动携带 Bearer 认证头）
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          }

          // 记录请求日志
          logger.network(
            options.method,
            options.uri.toString(),
            data: options.data,
          );

          handler.next(options);
        },
        onResponse: (response, handler) {
          // 记录响应日志
          logger.networkResponse(
            response.statusCode ?? 0,
            response.requestOptions.uri.toString(),
            data: response.data,
          );

          handler.next(response);
        },
        onError: (error, handler) {
          // 记录错误日志
          logger.networkError(
            error.requestOptions.method,
            error.requestOptions.uri.toString(),
            error.message,
          );
          // 打印响应体，帮助诊断服务端错误
          final responseData = error.response?.data;
          if (responseData != null) {
            logger.error('Error response body: $responseData');
          }

          handler.next(error);
        },
      ),
    );
  }

  /// GET 请求
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// POST 请求
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// PUT 请求
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// DELETE 请求
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 下载文件
  Future<Response> download(
    String urlPath,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    String lengthHeader = Headers.contentLengthHeader,
    Options? options,
  }) async {
    try {
      logger.info('📥 开始下载: $urlPath -> $savePath');
      return await dio.download(
        urlPath,
        savePath,
        onReceiveProgress: onReceiveProgress,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        deleteOnError: deleteOnError,
        lengthHeader: lengthHeader,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// 统一错误处理
  Exception _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException(l10n.networkConnectionTimeout);

      case DioExceptionType.badResponse:
        return _handleStatusCode(error.response?.statusCode);

      case DioExceptionType.cancel:
        return NetworkException(l10n.networkRequestCancelled);

      case DioExceptionType.connectionError:
        return NetworkException(l10n.networkConnectionFailed);

      case DioExceptionType.badCertificate:
        return NetworkException(l10n.networkCertificateFailed);

      case DioExceptionType.unknown:
        return NetworkException(l10n.networkRequestFailed(error.message ?? ''));
    }
  }

  /// 处理 HTTP 状态码
  Exception _handleStatusCode(int? statusCode) {
    switch (statusCode) {
      case 400:
        return NetworkException(l10n.networkBadRequest);
      case 401:
        return NetworkException(l10n.networkUnauthorized);
      case 403:
        return NetworkException(l10n.networkForbidden);
      case 404:
        return NetworkException(l10n.networkNotFound);
      case 500:
        return NetworkException(l10n.networkInternalServerError);
      case 502:
        return NetworkException(l10n.networkBadGateway);
      case 503:
        return NetworkException(l10n.networkServiceUnavailable);
      default:
        return NetworkException(
          l10n.networkRequestFailedWithCode((statusCode ?? 0).toString()),
        );
    }
  }
}

/// 网络异常类
class NetworkException implements Exception {
  final String message;

  NetworkException(this.message);

  @override
  String toString() => message;
}

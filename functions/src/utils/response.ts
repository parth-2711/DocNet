import { StandardSuccessResponse, StandardErrorResponse, ErrorCode } from '../types';

export function successResponse<T>(data: T, requestId = ''): StandardSuccessResponse<T> {
  return {
    success: true,
    data,
    error: null,
    requestId: requestId || `req-${Date.now().toString(36)}`
  };
}

export function errorResponse(
  code: ErrorCode | string,
  message: string,
  requestId = ''
): StandardErrorResponse {
  return {
    success: false,
    data: null,
    error: {
      code,
      message
    },
    requestId: requestId || `req-${Date.now().toString(36)}`
  };
}


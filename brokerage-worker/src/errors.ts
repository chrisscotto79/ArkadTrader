// An error with a message that's safe to show in the app.

export class ApiError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
  }
}

/** A failed SnapTrade or Google call. Logged in full, never shown to the user. */
export class UpstreamError extends Error {
  constructor(
    readonly service: string,
    readonly status: number,
    readonly body: string,
  ) {
    super(`${service} returned ${status}`);
  }
}

export const safeNextPath = (path, fallback = "/", origin) => {
  if (typeof path !== "string" || !path.startsWith("/")) return fallback;

  const currentOrigin =
    origin ?? (typeof window === "undefined" ? undefined : window.location.origin);

  try {
    const url = new URL(path, currentOrigin);
    return url.origin === currentOrigin ? `${url.pathname}${url.search}${url.hash}` : fallback;
  } catch {
    return fallback;
  }
};

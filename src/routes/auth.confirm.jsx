import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { useEffect, useRef, useState } from "react";
import { safeNextPath } from "@/lib/safe-next-path";
import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/auth/confirm")({
  ssr: false,
  validateSearch: (params) => ({
    token_hash: typeof params.token_hash === "string" ? params.token_hash : "",
    type: typeof params.type === "string" ? params.type : "",
    next: typeof params.next === "string" ? params.next : "",
  }),
  component: AuthConfirm,
});

function AuthConfirm() {
  const { token_hash, type, next } = Route.useSearch();
  const navigate = useNavigate();
  const [error, setError] = useState(null);
  const started = useRef(false);

  useEffect(() => {
    // The emailed link can fire this twice (React 18/19 StrictMode double-invoke).
    // verifyOtp is one-shot: a second call would invalidate the session it just created.
    if (started.current) return;
    started.current = true;

    (async () => {
      if (!token_hash || !type) {
        setError("No token hash or type");
        return;
      }

      const { error } = await supabase.auth.verifyOtp({ type, token_hash });
      if (error) {
        setError(error.message);
        return;
      }

      // Verification succeeded and the session is now persisted by the browser
      // client, so the destination (e.g. /auth/update-password) can use it.
      navigate({ href: safeNextPath(next, "/app") });
    })();
  }, [token_hash, type, next, navigate]);

  if (error) {
    return (
      <div className="flex min-h-svh w-full items-center justify-center p-6 md:p-10">
        <div className="w-full max-w-sm space-y-4 text-center">
          <h1 className="font-serif italic text-2xl">Something went wrong.</h1>
          <p className="text-sm text-muted-foreground">{error}</p>
          <a
            href="/auth"
            className="text-sm font-semibold text-primary underline underline-offset-4"
          >
            Back to sign in
          </a>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-svh w-full items-center justify-center p-6 md:p-10">
      <div className="text-sm text-muted-foreground">Confirming your email…</div>
    </div>
  );
}

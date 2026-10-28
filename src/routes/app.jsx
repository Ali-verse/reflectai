import { createFileRoute, Outlet, useNavigate } from "@tanstack/react-router";
import { useEffect } from "react";
import { AppShell } from "@/components/AppShell";
import { useAuth } from "@/lib/auth-context";
import { supabase } from "@/integrations/supabase/client";

export const Route = createFileRoute("/app")({
  ssr: false,
  component: AppLayout,
});

function AppLayout() {
  const { session, loading } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    let active = true;
    if (!loading && !session) {
      supabase.auth.getSession().then(({ data }) => {
        if (active && !data?.session) {
          navigate({ to: "/auth", replace: true });
        }
      });
    }
    return () => {
      active = false;
    };
  }, [session, loading, navigate]);

  if (loading || !session) {
    return (
      <div className="min-h-screen grid place-items-center bg-surface">
        <div className="text-sm text-muted-foreground">Loading your journal…</div>
      </div>
    );
  }

  return (
    <AppShell>
      <Outlet />
    </AppShell>
  );
}

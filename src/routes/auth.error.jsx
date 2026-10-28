import { createFileRoute } from "@tanstack/react-router";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export const Route = createFileRoute("/auth/error")({
  ssr: false,
  validateSearch: (params) => ({
    error: typeof params.error === "string" ? params.error : "",
  }),
  component: AuthError,
});

function AuthError() {
  const { error } = Route.useSearch();

  return (
    <div className="flex min-h-svh w-full items-center justify-center p-6 md:p-10">
      <div className="w-full max-w-sm">
        <div className="flex flex-col gap-6">
          <Card>
            <CardHeader>
              <CardTitle className="font-medium text-lg tracking-normal">
                Sorry, something went wrong.
              </CardTitle>
            </CardHeader>
            <CardContent>
              {error ? (
                <p className="text-sm text-muted-foreground">Code error: {error}</p>
              ) : (
                <p className="text-sm text-muted-foreground">An unspecified error occurred.</p>
              )}
              <a href="/auth" className="mt-4 inline-block text-sm underline underline-offset-4">
                Back to sign in
              </a>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}

import { createFileRoute } from "@tanstack/react-router";
import { UpdatePasswordForm } from "@/components/update-password-form";

export const Route = createFileRoute("/auth/update-password")({
  ssr: false,
  head: () => ({
    meta: [{ title: "Choose a new password — ReflectAI" }],
  }),
  component: AuthUpdatePassword,
});

function AuthUpdatePassword() {
  return (
    <div className="flex min-h-svh w-full items-center justify-center bg-surface p-6 md:p-10">
      <div className="w-full max-w-sm">
        <UpdatePasswordForm />
      </div>
    </div>
  );
}

import { createFileRoute } from "@tanstack/react-router";
import { ForgotPasswordForm } from "@/components/forgot-password-form";

export const Route = createFileRoute("/auth/forgot-password")({
  ssr: false,
  head: () => ({
    meta: [{ title: "Reset password — ReflectAI" }],
  }),
  component: AuthForgotPassword,
});

function AuthForgotPassword() {
  return (
    <div className="flex min-h-svh w-full items-center justify-center bg-surface p-6 md:p-10">
      <div className="w-full max-w-sm">
        <ForgotPasswordForm />
      </div>
    </div>
  );
}

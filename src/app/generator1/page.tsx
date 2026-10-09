import { SessionRealtimeGate } from "@/components/demo/SessionRealtimeGate";
import { resolveServerSessionIdentity } from "@/lib/session-id";
import { GeneratorClient } from "@/components/generator/GeneratorClient";

type Props = {
  searchParams: Promise<{ session?: string }>;
};

export default async function Generator1Page({ searchParams }: Props) {
  const { sessionId, routeSessionId } = await resolveServerSessionIdentity({
    searchParams: await searchParams,
  });

  return (
    <>
      <SessionRealtimeGate sessionId={sessionId ?? ""} routeSessionId={routeSessionId ?? undefined} />
      <GeneratorClient sessionId={sessionId} variant="generator1" />
    </>
  );
}

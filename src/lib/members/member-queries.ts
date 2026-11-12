import "server-only";

import { supabaseAuthServer } from "@/lib/supabase/auth-server";

export type MemberRequest = {
  id: string;
  kind: string;
  title: string;
  details: string | null;
  status: string;
  created_at: string;
};

/**
 * Declined requests are hidden from the member — the row is kept so admin still
 * has the record. Un-declining (status back to open/planned) makes it reappear.
 */
export async function getMyRequests(): Promise<MemberRequest[]> {
  const supabase = await supabaseAuthServer();
  const { data, error } = await supabase
    .from("member_requests")
    .select("id,kind,title,details,status,created_at")
    .neq("status", "declined")
    .order("created_at", { ascending: false });
  if (error) return [];
  return (data ?? []) as MemberRequest[];
}

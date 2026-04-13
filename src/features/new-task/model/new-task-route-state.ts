export function isNewTaskModalOpen(search: string): boolean {
  return new URLSearchParams(search).get("newTask") === "1";
}

export function buildNewTaskModalSearch(search: string, open: boolean): string {
  const params = new URLSearchParams(search);
  if (open) {
    params.delete("modal");
    params.set("newTask", "1");
  } else {
    params.delete("newTask");
  }
  const nextSearch = params.toString();
  return nextSearch ? `?${nextSearch}` : "";
}

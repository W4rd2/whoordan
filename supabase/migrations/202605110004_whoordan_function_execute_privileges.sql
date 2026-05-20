do $$
begin
  if to_regprocedure('public.set_updated_at()') is not null then
    execute 'revoke all on function public.set_updated_at() from public';
    execute 'revoke all on function public.set_updated_at() from anon';
    execute 'revoke all on function public.set_updated_at() from authenticated';
  end if;

  if to_regprocedure('public.rls_auto_enable()') is not null then
    execute 'revoke all on function public.rls_auto_enable() from public';
    execute 'revoke all on function public.rls_auto_enable() from anon';
    execute 'revoke all on function public.rls_auto_enable() from authenticated';
  end if;
end $$;

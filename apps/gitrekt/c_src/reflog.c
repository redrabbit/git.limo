#include "geef.h"
#include "repository.h"
#include "reference.h"
#include "oid.h"
#include "signature.h"
#include <string.h>
#include <git2.h>

ERL_NIF_TERM
geef_reflog_count(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	git_reflog *reflog;
	geef_repository *repo;
	ErlNifBinary bin;
	int error;
	size_t count;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], &bin))
		return enif_make_badarg(env);

	if (!geef_terminate_binary(&bin))
		return geef_oom(env);

	error = git_reflog_read(&reflog, repo->repo, (char *)bin.data);
	if (error < 0)
		return geef_error_struct(env, error);

	count = git_reflog_entrycount(reflog);
	git_reflog_free(reflog);

	return enif_make_tuple2(env, atoms.ok, enif_make_uint64(env, count));
}

ERL_NIF_TERM
geef_reflog_read(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	git_reflog *reflog;
	geef_repository *repo;
	ErlNifBinary bin;
	int error;
	size_t count, i;
	ERL_NIF_TERM list;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], &bin))
		return enif_make_badarg(env);

	if (!geef_terminate_binary(&bin))
		return geef_oom(env);

	error = git_reflog_read(&reflog, repo->repo, (char *)bin.data);
	if (error < 0)
		return geef_error_struct(env, error);

	count = git_reflog_entrycount(reflog);
	list = enif_make_list(env, 0);

	for (i = count; i > 0; i--) {
		ErlNifBinary id_old, id_new, message;
		ERL_NIF_TERM tentry, name, email, time, offset;
		const git_reflog_entry *entry;

		entry = git_reflog_entry_byindex(reflog, i-1);

		if (geef_oid_bin(&id_old, git_reflog_entry_id_old(entry)))
			goto on_oom;

		if (geef_oid_bin(&id_new, git_reflog_entry_id_new(entry)))
			goto on_oom;

		if (geef_signature_to_erl(&name, &email, &time, &offset,
					  env, git_reflog_entry_committer(entry)))
			goto on_oom;

		if (geef_string_to_bin(&message, git_reflog_entry_message(entry)))
			goto on_oom;

		tentry = enif_make_tuple7(env, name, email, time, offset,
					  enif_make_binary(env, &id_old),
					  enif_make_binary(env, &id_new),
					  enif_make_binary(env, &message));
		list = enif_make_list_cell(env, tentry, list);
	}

	git_reflog_free(reflog);
	return enif_make_tuple2(env, atoms.ok, list);

on_oom:
	git_reflog_free(reflog);
	return geef_oom(env);
}

ERL_NIF_TERM
geef_reflog_delete(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_repository *repo;
	ErlNifBinary bin;
	int error;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], &bin))
		return enif_make_badarg(env);

	if (!geef_terminate_binary(&bin))
		return geef_oom(env);

	error = git_reflog_delete(repo->repo, (char *) bin.data);

	enif_release_binary(&bin);

	return error < 0 ? geef_error_struct(env, error) : atoms.ok;
}

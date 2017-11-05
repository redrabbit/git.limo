#include "geef.h"
#include "repository.h"
#include "reference.h"
#include "oid.h"
#include <string.h>
#include <git2.h>

ERL_NIF_TERM
geef_reference_list(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	size_t i;
	git_strarray array;
	geef_repository *repo;
	ERL_NIF_TERM list;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	if (git_reference_list(&array, repo->repo) < 0)
		return geef_error(env);

	list = enif_make_list(env, 0);
	for (i = 0; i < array.count; i++) {
		ErlNifBinary bin;
		size_t len = strlen(array.strings[i]);

		if (!enif_alloc_binary(len, &bin))
			goto on_error;

		memcpy(bin.data, array.strings[i], len);
		list = enif_make_list_cell(env, enif_make_binary(env, &bin), list);
	}

	git_strarray_free(&array);

	return list;

on_error:
	git_strarray_free(&array);
	return geef_oom(env);
}

static int ref_target(ERL_NIF_TERM *out, ErlNifEnv *env, git_reference *ref)
{
	ErlNifBinary bin;

	if (git_reference_type(ref) == GIT_REF_OID) {
		const git_oid *id;
		id = git_reference_target(ref);

		if (geef_oid_bin(&bin, id) < 0)
			return -1;
	} else {
		const char *name;
		size_t len;

		name = git_reference_symbolic_target(ref);
		len = strlen(name);

		if (enif_alloc_binary(len, &bin) < 0)
			return -1;

		memcpy(bin.data, name, len);
	}

	*out = enif_make_binary(env, &bin);
	return 0;
}

static ERL_NIF_TERM ref_type(git_reference *ref)
{
	ERL_NIF_TERM type;

	switch (git_reference_type(ref)) {
	case GIT_REF_OID:
		type = atoms.oid;
		break;
	case GIT_REF_SYMBOLIC:
		type = atoms.symbolic;
		break;
	default:
		type = atoms.error;
		break;
	}

	return type;
}

ERL_NIF_TERM
geef_reference_lookup(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_repository *repo;
	git_reference *ref = NULL;
	ERL_NIF_TERM target, type;
	ErlNifBinary bin;
	int error;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	if (!enif_inspect_iolist_as_binary(env, argv[1], &bin))
		return enif_make_badarg(env);

	if (!geef_terminate_binary(&bin))
		goto on_oom;

	error = git_reference_lookup(&ref, repo->repo, (char *)bin.data);
	enif_release_binary(&bin);
	if (error < 0)
		return geef_error(env);

	type = ref_type(ref);
	if (ref_target(&target, env, ref) < 0)
		goto on_oom;

	return enif_make_tuple3(env, atoms.ok, type, target);

on_oom:
	git_reference_free(ref);
	enif_release_binary(&bin);

	return geef_oom(env);
}

ERL_NIF_TERM
geef_reference_iterator(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	ErlNifBinary bin;
	int globbing, error;
	geef_repository *repo;
	ERL_NIF_TERM term_iter;
	geef_ref_iter *res_iter;
	git_reference_iterator *iter;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);


	if (enif_is_identical(argv[1], atoms.undefined)) {
		globbing = 0;
	} else if (enif_inspect_iolist_as_binary(env, argv[1], &bin)) {
		globbing = 1;
	} else {
		return enif_make_badarg(env);
	}

	if (globbing && !geef_terminate_binary(&bin))
	    return atoms.error;

	if (globbing)
		error = git_reference_iterator_glob_new(&iter, repo->repo, (char *) bin.data);
	else
		error = git_reference_iterator_new(&iter, repo->repo);

	if (error < 0)
		return geef_error(env);

	res_iter = enif_alloc_resource(geef_ref_iter_type, sizeof(geef_ref_iter));
	res_iter->iter = iter;
	res_iter->repo = repo;
	enif_keep_resource(repo);
	term_iter = enif_make_resource(env, res_iter);
	enif_release_resource(res_iter);

	return enif_make_tuple2(env, atoms.ok, term_iter);
}

ERL_NIF_TERM
geef_reference_next(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	size_t len;
	const char *name;
	git_reference *ref;
	ErlNifBinary bin;
	geef_ref_iter *iter;
	ERL_NIF_TERM type, target;

	if (!enif_get_resource(env, argv[0], geef_ref_iter_type, (void **) &iter))
		return enif_make_badarg(env);

	error = git_reference_next(&ref, iter->iter);
	if (error == GIT_ITEROVER)
		return enif_make_tuple2(env, atoms.error, atoms.iterover);
	if (error < 0)
		return geef_error(env);

	type = ref_type(ref);
	if (ref_target(&target, env, ref) < 0) {
		git_reference_free(ref);
		return geef_oom(env);
	}

	name = git_reference_name(ref);
	len = strlen(name);
	if (!enif_alloc_binary(len, &bin)) {
		git_reference_free(ref);
		return geef_oom(env);
	}

	memcpy(bin.data, name, len);

	return enif_make_tuple4(env, atoms.ok, enif_make_binary(env, &bin), type, target);
}

void geef_ref_iter_free(ErlNifEnv *env, void *cd)
{
	geef_ref_iter *ref = (geef_ref_iter *) cd;
	git_reference_iterator_free(ref->iter);
	enif_release_resource(ref->repo);
}

ERL_NIF_TERM
geef_reference_resolve(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	size_t len;
	const char *name;
	ErlNifBinary bin, id;
	geef_repository *repo;
	git_reference *ref, *resolved;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], &bin))
		return enif_make_badarg(env);

	if (!geef_terminate_binary(&bin))
		return geef_oom(env);

	if (git_reference_lookup(&ref, repo->repo, (char *) bin.data) < 0)
		return geef_error(env);

	if (git_reference_resolve(&resolved, ref) < 0)
		return geef_error(env);

	git_reference_free(ref);
	name = git_reference_name(resolved);
	len = strlen(name);

	if (enif_realloc_binary(&bin, len) < 0)
		goto on_oom;

	memcpy(bin.data, name, len);

	if (geef_oid_bin(&id, git_reference_target(resolved)) < 0)
		goto on_oom;

	git_reference_free(resolved);

	return enif_make_tuple3(env, atoms.ok, enif_make_binary(env, &bin), enif_make_binary(env, &id));

on_oom:
	git_reference_free(resolved);
	return geef_oom(env);
}

ERL_NIF_TERM
geef_reference_dwim(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	ErlNifBinary bin;
	ERL_NIF_TERM target, type;
	geef_repository *repo;
	git_reference *ref;
	const char *name;
	size_t len;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	if (!enif_inspect_iolist_as_binary(env, argv[1], &bin))
		return enif_make_badarg(env);

	if (!geef_terminate_binary(&bin))
		return geef_oom(env);

	if (git_reference_dwim(&ref, repo->repo, (char *)bin.data) < 0) {
		enif_release_binary(&bin);
		return geef_error(env);
	}

	type = ref_type(ref);
	if (ref_target(&target, env, ref) < 0) {
		git_reference_free(ref);
		return geef_oom(env);
	}

	name = git_reference_name(ref);
	len = strlen(name);
	if (!enif_realloc_binary(&bin, len)) {
		git_reference_free(ref);
		enif_release_binary(&bin);
	}

	memcpy(bin.data, name, len);

	return enif_make_tuple4(env, atoms.ok, enif_make_binary(env, &bin), type, target);
}

struct list_data {
	ErlNifEnv *env;
	ERL_NIF_TERM list;
};

static int append_to_list(const char *name, void *payload)
{
	struct list_data *data = (struct list_data *) payload;
	ErlNifBinary bin;
	size_t len = strlen(name);

	if (!enif_alloc_binary(len, &bin))
		return -1;

	memcpy(bin.data, name, len);
	data->list = enif_make_list_cell(data->env, enif_make_binary(data->env, &bin), data->list);
	return 0;
}

ERL_NIF_TERM
geef_reference_glob(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	geef_repository *repo;
	ErlNifBinary bin;
	struct list_data data;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	if (!enif_inspect_iolist_as_binary(env, argv[1], &bin))
		return enif_make_badarg(env);

	if (!geef_terminate_binary(&bin))
		return geef_oom(env);

	data.env = env;
	data.list = enif_make_list(env, 0);

	error = git_reference_foreach_glob(repo->repo, (char *) bin.data, append_to_list, &data);

	enif_release_binary(&bin);
	if (error < 0)
		return geef_error(env);

	return data.list;
}

ERL_NIF_TERM
geef_reference_to_id(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_repository *repo;
	ErlNifBinary bin;
	git_oid id;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	if (!enif_inspect_iolist_as_binary(env, argv[1], &bin))
		return enif_make_badarg(env);

	if (!geef_terminate_binary(&bin))
		return geef_oom(env);

	if (git_reference_name_to_id(&id, repo->repo, (char *)bin.data) < 0)
		return geef_error(env);

	if (geef_oid_bin(&bin, &id) < 0)
		return geef_oom(env);

	return enif_make_tuple2(env, atoms.ok, enif_make_binary(env, &bin));
}

ERL_NIF_TERM
geef_reference_create(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_repository *repo;
	ErlNifBinary name, target;
	int error, force;
	git_reference *ref = NULL;
	const char *pname, *ptarget;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	if (!enif_inspect_iolist_as_binary(env, argv[1], &name))
		return enif_make_badarg(env);

	if (!enif_inspect_iolist_as_binary(env, argv[3], &target))
		return enif_make_badarg(env);

	if (!geef_terminate_binary(&name))
		return geef_oom(env);

	force = enif_is_identical(argv[4], atoms.true);

	pname = (const char *) name.data;
	if (enif_is_identical(argv[2], atoms.oid)) {
		const git_oid *oid = (const git_oid *) target.data;
		error = git_reference_create(&ref, repo->repo, pname, oid, force, NULL);
	} else if (enif_is_identical(argv[2], atoms.symbolic)) {
		if (!geef_terminate_binary(&target))
			return geef_oom(env);

		ptarget = (const char *) target.data;
		error = git_reference_symbolic_create(&ref, repo->repo, pname, ptarget, force, NULL);
		enif_release_binary(&target);
	} else {
		enif_release_binary(&target);
		enif_release_binary(&name);
		return enif_make_badarg(env);
	}

	git_reference_free(ref);
	enif_release_binary(&name);

	if (error < 0)
		return geef_error(env);

	return atoms.ok;
}

ERL_NIF_TERM
geef_reference_has_log(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_repository *repo;
	ErlNifBinary name;
	int error;
	const char *pname;
	ERL_NIF_TERM ret;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	if (!enif_inspect_iolist_as_binary(env, argv[1], &name))
		return enif_make_badarg(env);

	if (!geef_terminate_binary(&name))
		return geef_oom(env);

	pname = (char *) name.data;
	error = git_reference_has_log(repo->repo, pname);

	enif_release_binary(&name);

	if (error < 0)
		return geef_error(env);

	ret = error ? atoms.true : atoms.false;

	return enif_make_tuple2(env, atoms.ok, ret);
}

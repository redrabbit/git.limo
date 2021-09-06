#include <string.h>
#include <git2.h>
#include "geef.h"
#include "repository.h"
#include "oid.h"
#include "object.h"
#include "revparse.h"

ERL_NIF_TERM
geef_revparse_single(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	ErlNifBinary bin, id;
	geef_repository *repo;
	geef_object *obj;
	ERL_NIF_TERM type, term_obj;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], &bin))
		return enif_make_badarg(env);

	if (geef_terminate_binary(&bin) < 0)
		return geef_oom(env);

	obj = enif_alloc_resource(geef_object_type, sizeof(geef_object));
	if (!obj)
		return geef_oom(env);

	error = git_revparse_single(&obj->obj, repo->repo, (char *) bin.data);
	if (error < 0) {
		enif_release_binary(&bin);
		return geef_error_struct(env, error);
	}

	type = geef_object_type2atom(git_object_type(obj->obj));

	if (geef_oid_bin(&id, git_object_id(obj->obj)) < 0)
		return geef_oom(env);


	term_obj = enif_make_resource(env, obj);
	enif_release_resource(obj);

	obj->repo = repo;
	enif_keep_resource(repo);

	return enif_make_tuple4(env, atoms.ok, term_obj, type, enif_make_binary(env, &id));
}

ERL_NIF_TERM
geef_revparse_ext(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	int error;
	size_t len;
	const char *name;
	git_reference *ref = NULL;

	ErlNifBinary bin, id;
	geef_repository *repo;
	geef_object *obj;
	ERL_NIF_TERM type, term_obj;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], &bin))
		return enif_make_badarg(env);

	if (geef_terminate_binary(&bin) < 0)
		return geef_oom(env);

	obj = enif_alloc_resource(geef_object_type, sizeof(geef_object));
	if (!obj)
		return geef_oom(env);

	error = git_revparse_ext(&obj->obj, &ref, repo->repo, (char *) bin.data);
	if (error < 0) {
		enif_release_binary(&bin);
		return geef_error_struct(env, error);
	}

	if (ref) {
		name = git_reference_name(ref);
		len = strlen(name);
		if (!enif_realloc_binary(&bin, len)) {
			git_reference_free(ref);
			enif_release_binary(&bin);
			return geef_oom(env);
		}

		memcpy(bin.data, name, len);
		git_reference_free(ref);
	}

	type = geef_object_type2atom(git_object_type(obj->obj));

	if (geef_oid_bin(&id, git_object_id(obj->obj)) < 0)
		return geef_oom(env);

	term_obj = enif_make_resource(env, obj);
	enif_release_resource(obj);

	obj->repo = repo;
	enif_keep_resource(repo);

	return enif_make_tuple5(env, atoms.ok, term_obj, type, enif_make_binary(env, &id), ref ? enif_make_binary(env, &bin) : atoms.nil);
}

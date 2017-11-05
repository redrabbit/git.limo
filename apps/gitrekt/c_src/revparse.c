#include <git2.h>
#include "geef.h"
#include "repository.h"
#include "oid.h"
#include "object.h"
#include "revparse.h"

ERL_NIF_TERM
geef_revparse_single(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	ErlNifBinary bin, id;
	geef_repository *repo;
	geef_object *obj;
	ERL_NIF_TERM type, term_obj;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	if (!enif_inspect_iolist_as_binary(env, argv[1], &bin))
		return enif_make_badarg(env);

	if (geef_terminate_binary(&bin) < 0)
		return geef_oom(env);

	obj = enif_alloc_resource(geef_object_type, sizeof(geef_object));
	if (!obj)
		return geef_oom(env);

	if (git_revparse_single(&obj->obj, repo->repo, (char *) bin.data) < 0) {
		enif_release_binary(&bin);
		enif_release_resource(obj);
		return geef_error(env);
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

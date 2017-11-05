#include <git2.h>
#include <string.h>
#include <stdio.h>

#include "oid.h"
#include "geef.h"
#include "tree.h"

ERL_NIF_TERM
geef_tag_peel(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_object *obj, *peeled;
	ERL_NIF_TERM term_peeled;
	ErlNifBinary id;

	if (!enif_get_resource(env, argv[0], geef_object_type, (void **) &obj))
		return enif_make_badarg(env);

	if (git_object_type(obj->obj) != GIT_OBJ_TAG)
		return enif_make_badarg(env);

	peeled = enif_alloc_resource(geef_object_type, sizeof(geef_object));
	if (!obj)
		return geef_oom(env);

	if (git_tag_peel(&peeled->obj, (git_tag *)obj->obj) < 0)
		return geef_error(env);

	if(geef_oid_bin(&id, git_object_id(obj->obj)) < 0) {
		enif_release_resource(peeled);
		git_object_free(obj->obj);
		return geef_oom(env);
	}

	peeled->repo = obj->repo;
	enif_keep_resource(peeled->repo);

	term_peeled = enif_make_resource(env, peeled);
	enif_release_resource(peeled);

	return enif_make_tuple4(env, atoms.ok, geef_object_type2atom(git_object_type(peeled->obj)),
				enif_make_binary(env, &id), term_peeled);
}

#include <git2.h>
#include <string.h>
#include <stdio.h>

#include "geef.h"
#include "pathspec.h"

ERL_NIF_TERM
geef_pathspec_match_tree(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	geef_object *obj;
	git_strarray array;
	git_pathspec *pathspec;
	int match;

	if (!enif_get_resource(env, argv[0], geef_object_type, (void **) &obj))
		return enif_make_badarg(env);

	array = git_strarray_from_list(env, argv[1]);
	if(git_pathspec_new(&pathspec, &array) < 0) {
		git_strarray_free(&array);
		return enif_make_badarg(env);
	}

	match = git_pathspec_match_tree(NULL, (git_tree *)obj->obj, GIT_PATHSPEC_NO_MATCH_ERROR, pathspec);

	git_pathspec_free(pathspec);

	if (match == 0)
		return enif_make_tuple2(env, atoms.ok, atoms.true);
	else
		return enif_make_tuple2(env, atoms.ok, atoms.false);
}

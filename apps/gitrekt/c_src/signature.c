#include "geef.h"
#include "repository.h"
#include <string.h>
#include <git2.h>

int geef_signature_from_erl(git_signature **out, ErlNifEnv *env, ERL_NIF_TERM *err, ERL_NIF_TERM term)
{
	int error;
	const ERL_NIF_TERM *tuple;
	ErlNifBinary name, email;
	git_signature *sig;
	git_time_t gtime;
	int offset, arity;

	memset(&name, 0, sizeof(ErlNifBinary));
	memset(&email, 0, sizeof(ErlNifBinary));

	if (!enif_get_tuple(env, term, &arity, &tuple))
		goto on_badarg;

	if (arity != 4)
		goto on_badarg;

	if (!enif_inspect_binary(env, tuple[0], &name))
		goto on_badarg;

	if (!enif_inspect_binary(env, tuple[1], &email))
		goto on_badarg;

	if (!geef_terminate_binary(&name))
		goto on_oom;

	if (!geef_terminate_binary(&email))
		goto on_oom;

	if (!enif_get_uint(env, tuple[2], &gtime))
		goto on_badarg;

	if (!enif_get_int(env, tuple[3], &offset))
		goto on_badarg;

	error = git_signature_new(&sig, (char *)name.data, (char *)email.data, gtime, offset);
	if (error < 0) {
		enif_release_binary(&name);
		enif_release_binary(&email);
		*err = geef_error_struct(env, error);
		return -1;
	}

	*out = sig;
	return 0;

on_badarg:
		enif_release_binary(&name);
		enif_release_binary(&email);
		*err = enif_make_badarg(env);
		return -1;

on_oom:
		enif_release_binary(&name);
		enif_release_binary(&email);
		*err = geef_oom(env);
		return -1;

}

int geef_signature_to_erl(ERL_NIF_TERM *out_name, ERL_NIF_TERM *out_email, ERL_NIF_TERM *out_time, ERL_NIF_TERM *out_offset, ErlNifEnv *env, const git_signature *sig)
{
	ErlNifBinary name, email;

	memset(&name, 0, sizeof(ErlNifBinary));
	memset(&email, 0, sizeof(ErlNifBinary));

	if (geef_string_to_bin(&name, sig->name) < 0)
		goto oom;

	if (geef_string_to_bin(&email, sig->email) < 0)
		goto oom;

	*out_name   = enif_make_binary(env, &name);
	*out_email  = enif_make_binary(env, &email);
	*out_time   = enif_make_ulong(env, sig->when.time);
	*out_offset = enif_make_uint(env, sig->when.offset);

	return 0;

oom:
	enif_release_binary(&name);
	enif_release_binary(&email);
	return -1;
}

ERL_NIF_TERM
geef_signature_default(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	git_signature *sig;
	geef_repository *repo;
	ERL_NIF_TERM name, email, time, offset;
	int error;

	if (!enif_get_resource(env, argv[0], geef_repository_type, (void **) &repo))
		return enif_make_badarg(env);

	error = git_signature_default(&sig, repo->repo);
	if (error < 0)
		return geef_error_struct(env, error);

	error = geef_signature_to_erl(&name, &email, &time, &offset, env, sig);
	git_signature_free(sig);

	if (error < 0)
		return geef_oom(env);

	return enif_make_tuple5(env, atoms.ok, name, email, time, offset);
}

ERL_NIF_TERM
geef_signature_new(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
	ErlNifBinary name, email;
	git_signature *sig;
	size_t len;
	int error;
	unsigned int at;

	if (!enif_inspect_binary(env, argv[0], &name))
		return enif_make_badarg(env);

	if (!enif_inspect_binary(env, argv[1], &email))
		return enif_make_badarg(env);

	if (argc == 3 && !enif_get_uint(env, argv[2], &at))
		return enif_make_badarg(env);

	if (!geef_terminate_binary(&name))
		return atoms.error;

	if (!geef_terminate_binary(&email)) {
		enif_release_binary(&name);
		return atoms.error;
	}

	if (argc == 3)
		error = git_signature_now(&sig, (char *)name.data, (char *)email.data);
	else
		error = git_signature_new(&sig, (char *)name.data, (char *)email.data, at, 0);

	if (error < 0)
		return geef_error_struct(env, error);

	len = strlen(sig->name);
	if (!enif_realloc_binary(&name, len))
		goto on_error;

	memcpy(name.data, sig->name, len);

	len = strlen(sig->email);
	if (!enif_realloc_binary(&email, len))
		goto on_error;

	memcpy(email.data, sig->email, len);
	git_signature_free(sig);

	if (argc == 3)
		return enif_make_tuple3(env, atoms.ok, enif_make_binary(env, &name), enif_make_binary(env, &email));

	return enif_make_tuple5(env, atoms.ok,
	         enif_make_binary(env, &name), enif_make_binary(env, &email),
		 enif_make_ulong(env, sig->when.time), enif_make_uint(env, sig->when.offset));

on_error:
		git_signature_free(sig);
		enif_release_binary(&name);
		enif_release_binary(&email);

		return atoms.error;
}

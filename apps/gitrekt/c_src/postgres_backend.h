#ifdef PGSQL_BACKEND
#ifndef GEEF_BACKEND_H
#define GEEF_BACKEND_H

#include <git2.h>
#include <libpq-fe.h>

int pq_connect(PGconn **conn, const char *conn_info);
int git_odb_backend_postgres(git_odb_backend **backend_out, PGconn *conn, int64_t repo_id);
int git_refdb_backend_postgres(git_refdb_backend **backend_out, PGconn *conn, int64_t repo_id);

#endif
#endif

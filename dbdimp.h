/* Relentlessly copied from DBD-Oracle (one has to start somewhere ...) */

#if defined(get_no_modify) && !defined(no_modify)
# define no_modify PL_no_modify
# endif

/* I really like this one in perl ... */
#define	unless(e)	if (!(e))

/* ====== Include Unify Header Files ====== */

#include <dbtypes.h>
#include <fdesc.h>

typedef	unsigned char	byte;

/* ------ end of Unify include files ------ */


/* ====== define data types ====== */

typedef struct imp_fbh_st imp_fbh_t;

struct imp_drh_st {
    dbih_drc_t	com;		/* MUST be first element in structure	*/
    };

/* Define dbh implementor data structure */
struct imp_dbh_st {
    dbih_dbc_t	com;		/* MUST be first element in structure	*/
    };

/* Define sth implementor data structure */
struct imp_sth_st {
    dbih_stc_t	com;		/* MUST be first element in structure	*/

    short	id;		/* Statement ID, for dynamic naming	*/

    char	*statement;	/* Statement text			*/
    };

/* These defines avoid name clashes for multiple statically linked DBD's	*/

#define dbd_init            uni_init
#define dbd_db_login        uni_db_login
#define dbd_db_do           uni_db_do
#define dbd_db_commit       uni_db_commit
#define dbd_db_rollback     uni_db_rollback
#define dbd_db_disconnect   uni_db_disconnect
#define dbd_db_destroy      uni_db_destroy
#define dbd_db_STORE_attrib uni_db_STORE_attrib
#define dbd_db_FETCH_attrib uni_db_FETCH_attrib
#define dbd_st_prepare      uni_st_prepare
#define dbd_st_rows         uni_st_rows
#define dbd_st_execute      uni_st_execute
#define dbd_st_fetch        uni_st_fetch
#define dbd_st_finish       uni_st_finish
#define dbd_st_destroy      uni_st_destroy
#define dbd_st_blob_read    uni_st_blob_read
#define dbd_st_STORE_attrib uni_st_STORE_attrib
#define dbd_st_FETCH_attrib uni_st_FETCH_attrib
#define dbd_describe        uni_describe
#define dbd_bind_ph         uni_bind_ph

/* end */

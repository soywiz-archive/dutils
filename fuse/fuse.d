extern (system)
{
	struct fuse;
	struct fuse_cmd;
	struct fuse_FS;

	alias int function(void *buf, char *name, stat *stbuf, off_t off) fuse_fill_dir_t;
	alias int function(fuse_dirhandle *h, char *name, int type, ino_t ino) fuse_dirfil_t;

	//typedef fuse_dirhandle *fuse_dirh_t;

	struct fuse_operations
	{
		int   function(char *, stat *)                 getattr;
		int   function(char *, char *, size_t)         readlink;
		int   function(char *, char *, size_t)         readlink;
		int   function(char *, fuse_dirhandle *, fuse_dirfil_t) getdir; // deprecated
		int   function(char *, mode_t, dev_t)          mknod;
		int   function(char *, mode_t)                 mkdir;
		int   function(char *)                         unlink;
		int   function(char *)                         rmdir;
		int   function(char *, char *)                 symlink;
		int   function(char *, char *)                 rename;
		int   function(char *, char *)                 link;
		int   function(char *, mode_t)                 chmod;
		int   function(char *, uid_t, gid_t)           chown;
		int   function(char *, off_t)                  truncate;
		int   function(char *, utimbuf *) utime; // deprecated
		int   function(char *, fuse_file_info *)       open;
		int   function(char *, char *, size_t, off_t, fuse_file_info *) read;
		int   function(char *, char *, size_t, off_t, fuse_file_info *) write;
		int   function(char *, statvfs *)              statfs;
		int   function(char *, fuse_file_info *)       flush;
		int   function(char *, fuse_file_info *)       release;
		int   function(char *, int, fuse_file_info *)  fsync;
		int   function(char *, char *, char *, size_t, int) setxattr;
		int   function(char *, char *, char *, size_t) getxattr;
		int   function(char *, char *, size_t)         listxattr;
		int   function(char *, char *)                 removexattr;
		int   function(char *, fuse_file_info *)       opendir;
		int   function(char *, void *, fuse_fill_dir_t, off_t, fuse_file_info *) readdir;
		int   function(char *, fuse_file_info *)       releasedir;
		int   function(char *, int, fuse_file_info *)  fsyncdir;
		void* function(fuse_conn_info *conn) init;
		void  function(void *) destroy;
		int   function(char *, int) access;
		int   function(char *, mode_t, fuse_file_info *) create;
		int   function(char *, off_t, fuse_file_info *)  ftruncate;
		int   function(char *, stat *, fuse_file_info *) fgetattr;
		int   function(char *, fuse_file_info *, int cmd, flock *) lock;
		int   function(char *, timespec2]) utimens;
		int   function(char *, size_t, uint64_t *) bmap;
		uint  flags;
		int   function(char *, int cmd, void *arg, fuse_file_info *, uint flags, void *data) ioctl;
		int   function(char *, fuse_file_info *, fuse_pollhandle *ph, uint *reventsp) poll;
	}

	fuse_context
	{
		/** Pointer to the fuse object */
		fuse *_fuse;

		uid_t uid; // User ID of the calling process
		gid_t gid; // Group ID of the calling process
		pid_t pid; // Thread ID of the calling process

		void *private_data; // Private filesystem data

		mode_t umask; // Umask of the calling process (introduced in version 2.8)
	}

	int   fuse_main_real(int argc, char *argv[], fuse_operations *op, size_t op_size, void *user_data);
	int   fuse_main(int argc, char *argv[], fuse_operations *op, void *user_data) { return fuse_main_real(argc, argv, op, fuse_operations.sizeof, user_data); }
	fuse* fuse_new(fuse_chan *ch, fuse_args *args, fuse_operations *op, size_t op_size, void *user_data);
	void  fuse_destroy(fuse *f);
	int   fuse_loop(fuse *f);
	void  fuse_exit(fuse *f);
	int   fuse_loop_mt(fuse *f);
	fuse_context *fuse_get_context();
	int   fuse_getgroups(int size, gid_t list[]);
	int   fuse_interrupted();
	int   fuse_invalidate(fuse *f, char *path);
	int   fuse_is_lib_option(char *opt);


	int  fuse_fs_getattr(fuse_fs *fs, char *path, stat *buf);
	int  fuse_fs_fgetattr(fuse_fs *fs, char *path, stat *buf, fuse_file_info *fi);
	int  fuse_fs_rename(fuse_fs *fs, char *oldpath, char *newpath);
	int  fuse_fs_unlink(fuse_fs *fs, char *path);
	int  fuse_fs_rmdir(fuse_fs *fs, char *path);
	int  fuse_fs_symlink(fuse_fs *fs, char *linkname, char *path);
	int  fuse_fs_link(fuse_fs *fs, char *oldpath, char *newpath);
	int  fuse_fs_release(fuse_fs *fs, char *path, fuse_file_info *fi);
	int  fuse_fs_open(fuse_fs *fs, char *path, fuse_file_info *fi);
	int  fuse_fs_read(fuse_fs *fs, char *path, char *buf, size_t size, off_t off, fuse_file_info *fi);
	int  fuse_fs_write(fuse_fs *fs, char *path, char *buf, size_t size, off_t off, fuse_file_info *fi);
	int  fuse_fs_fsync(fuse_fs *fs, char *path, int datasync, fuse_file_info *fi);
	int  fuse_fs_flush(fuse_fs *fs, char *path, fuse_file_info *fi);
	int  fuse_fs_statfs(fuse_fs *fs, char *path, statvfs *buf);
	int  fuse_fs_opendir(fuse_fs *fs, char *path, fuse_file_info *fi);
	int  fuse_fs_readdir(fuse_fs *fs, char *path, void *buf, fuse_fill_dir_t filler, off_t off, fuse_file_info *fi);
	int  fuse_fs_fsyncdir(fuse_fs *fs, char *path, int datasync, fuse_file_info *fi);
	int  fuse_fs_releasedir(fuse_fs *fs, char *path, fuse_file_info *fi);
	int  fuse_fs_create(fuse_fs *fs, char *path, mode_t mode, fuse_file_info *fi);
	int  fuse_fs_lock(fuse_fs *fs, char *path, fuse_file_info *fi, int cmd, flock *lock);
	int  fuse_fs_chmod(fuse_fs *fs, char *path, mode_t mode);
	int  fuse_fs_chown(fuse_fs *fs, char *path, uid_t uid, gid_t gid);
	int  fuse_fs_truncate(fuse_fs *fs, char *path, off_t size);
	int  fuse_fs_ftruncate(fuse_fs *fs, char *path, off_t size, fuse_file_info *fi);
	int  fuse_fs_utimens(fuse_fs *fs, char *path, timespec tv[2]);
	int  fuse_fs_access(fuse_fs *fs, char *path, int mask);
	int  fuse_fs_readlink(fuse_fs *fs, char *path, char *buf, size_t len);
	int  fuse_fs_mknod(fuse_fs *fs, char *path, mode_t mode, dev_t rdev);
	int  fuse_fs_mkdir(fuse_fs *fs, char *path, mode_t mode);
	int  fuse_fs_setxattr(fuse_fs *fs, char *path, char *name, char *value, size_t size, int flags);
	int  fuse_fs_getxattr(fuse_fs *fs, char *path, char *name, char *value, size_t size);
	int  fuse_fs_listxattr(fuse_fs *fs, char *path, char *list, size_t size);
	int  fuse_fs_removexattr(fuse_fs *fs, char *path, char *name);
	int  fuse_fs_bmap(fuse_fs *fs, char *path, size_t blocksize, uint64_t *idx);
	int  fuse_fs_ioctl(fuse_fs *fs, char *path, int cmd, void *arg, fuse_file_info *fi, uint flags, void *data);
	int  fuse_fs_poll(fuse_fs *fs, char *path, fuse_file_info *fi, fuse_pollhandle *ph, uint *reventsp);
	void fuse_fs_init(fuse_fs *fs, fuse_conn_info *conn);
	void fuse_fs_destroy(fuse_fs *fs);

	int  fuse_notify_poll(fuse_pollhandle *ph);
	fuse_fs *fuse_fs_new(fuse_operations *op, size_t op_size, void *user_data);

	struct fuse_module {
		char *name;
		fuse_fs * function(fuse_args *args, fuse_fs *fs[]) factory;
		fuse_module *next;
		fusemod_so *so;
		int ctr;
	}

	void fuse_register_module(fuse_module *mod);

	/*
	#define FUSE_REGISTER_MODULE(name_, factory_)				  \
		static __attribute__((constructor)) void name_ ## _register(void) \
		{								  \
			static fuse_module mod =				  \
				{ #name_, factory_, NULL, NULL, 0 };		  \
			fuse_register_module(&mod);				  \
		}
	*/
}
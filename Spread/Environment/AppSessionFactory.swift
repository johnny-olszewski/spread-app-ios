// Shims the session factory type for debug vs production builds.
#if DEBUG
typealias AppSessionFactory = DebugAppSessionFactory
#else
typealias AppSessionFactory = ProdAppSessionFactory
#endif

declare global {
    namespace Express {
      interface Request {
        subdomain?: string
      }
    }
  }
  
  
export default function handler(req, res) {
    // Get the subdomain from the header
    const subdomain = req.headers["x-subdomain"] || ""
  
    res.status(200).json({ subdomain })
  }
  
  
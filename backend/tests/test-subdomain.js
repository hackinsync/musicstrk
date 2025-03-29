// Simple script to test subdomain functionality
const testSubdomains = async () => {
    try {
      // Test main domain
      const mainResponse = await fetch("http://musicstrk.fun:8080")
      console.log("Main domain response:", mainResponse.status)
  
      // Test valid subdomain (assuming it exists in DB)
      const validResponse = await fetch("http://rebelwav.musicstrk.fun:8080")
      console.log("Valid subdomain response:", validResponse.status)
  
      // Test invalid subdomain
      const invalidResponse = await fetch("http://nonexistent.musicstrk.fun:8080")
      console.log("Invalid subdomain response:", invalidResponse.status)
  
      // Test reserved subdomain
      const reservedResponse = await fetch("http://api.musicstrk.fun:8080")
      console.log("Reserved subdomain response:", reservedResponse.status)
    } catch (error) {
      console.error("Error testing subdomains:", error)
    }
  }
  
  testSubdomains()
  
  
"use client"

import { useEffect, useState } from "react"
import Head from "next/head"

export default function Home() {
  const [subdomain, setSubdomain] = useState("")

  useEffect(() => {
    // Get the subdomain from the URL
    const hostname = window.location.hostname
    const parts = hostname.split(".")
    if (parts.length > 2) {
      setSubdomain(parts[0])
    }
  }, [])

  return (
    <div className="container">
      <Head>
        <title>{subdomain ? `${subdomain} - MusicStrk` : "MusicStrk"}</title>
        <link rel="icon" href="/favicon.ico" />
      </Head>

      <main>
        <h1 className="title">{subdomain ? `Welcome to ${subdomain}'s MusicStrk Site` : "Welcome to MusicStrk"}</h1>

        <p className="description">
          {subdomain ? `This is the artist page for ${subdomain}` : "Get started by creating your artist subdomain"}
        </p>

        <div className="grid">
          <div className="card">
            <h3>Artist Profile &rarr;</h3>
            <p>View and manage your artist profile.</p>
          </div>

          <div className="card">
            <h3>Music &rarr;</h3>
            <p>Upload and manage your music.</p>
          </div>

          <div className="card">
            <h3>Events &rarr;</h3>
            <p>Create and manage your events.</p>
          </div>

          <div className="card">
            <h3>Merchandise &rarr;</h3>
            <p>Sell your merchandise.</p>
          </div>
        </div>
      </main>

      <footer>
        <p>Powered by MusicStrk</p>
      </footer>

      <style jsx>{`
        .container {
          min-height: 100vh;
          padding: 0 0.5rem;
          display: flex;
          flex-direction: column;
          justify-content: center;
          align-items: center;
        }

        main {
          padding: 5rem 0;
          flex: 1;
          display: flex;
          flex-direction: column;
          justify-content: center;
          align-items: center;
        }

        footer {
          width: 100%;
          height: 100px;
          border-top: 1px solid #eaeaea;
          display: flex;
          justify-content: center;
          align-items: center;
        }

        footer p {
          display: flex;
          justify-content: center;
          align-items: center;
        }

        a {
          color: inherit;
          text-decoration: none;
        }

        .title {
          margin: 0;
          line-height: 1.15;
          font-size: 4rem;
          text-align: center;
        }

        .description {
          line-height: 1.5;
          font-size: 1.5rem;
          text-align: center;
        }

        .grid {
          display: flex;
          align-items: center;
          justify-content: center;
          flex-wrap: wrap;
          max-width: 800px;
          margin-top: 3rem;
        }

        .card {
          margin: 1rem;
          flex-basis: 45%;
          padding: 1.5rem;
          text-align: left;
          color: inherit;
          text-decoration: none;
          border: 1px solid #eaeaea;
          border-radius: 10px;
          transition: color 0.15s ease, border-color 0.15s ease;
        }

        .card:hover,
        .card:focus,
        .card:active {
          color: #0070f3;
          border-color: #0070f3;
        }

        .card h3 {
          margin: 0 0 1rem 0;
          font-size: 1.5rem;
        }

        .card p {
          margin: 0;
          font-size: 1.25rem;
          line-height: 1.5;
        }

        @media (max-width: 600px) {
          .grid {
            width: 100%;
            flex-direction: column;
          }
        }
      `}</style>

      <style jsx global>{`
        html,
        body {
          padding: 0;
          margin: 0;
          font-family: -apple-system, BlinkMacSystemFont, Segoe UI, Roboto,
            Oxygen, Ubuntu, Cantarell, Fira Sans, Droid Sans, Helvetica Neue,
            sans-serif;
        }

        * {
          box-sizing: border-box;
        }
      `}</style>
    </div>
  )
}


// pages/api/image-proxy.ts

import type { NextApiRequest, NextApiResponse } from 'next'
import https from 'https'

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  const imageUrl = req.query.url as string

  if (!imageUrl || !imageUrl.startsWith('https://')) {
    return res.status(400).send('Invalid image URL')
  }

  try {
    https.get(imageUrl, (imageRes) => {
      if (imageRes.statusCode && imageRes.statusCode >= 400) {
        res.status(imageRes.statusCode).send('Failed to load image')
        return
      }

      res.setHeader('Content-Type', imageRes.headers['content-type'] || 'image/jpeg')
      imageRes.pipe(res)

      imageRes.on('end', () => {
        res.end()
      })

      imageRes.on('error', (err) => {
        console.error('Stream error:', err)
        res.status(500).send('Image stream failed')
      })
    }).on('error', (err) => {
      console.error('Request error:', err)
      res.status(500).send('Failed to request image')
    })
  } catch (err) {
    console.error('Unexpected error:', err)
    res.status(500).send('Unexpected error')
  }
}

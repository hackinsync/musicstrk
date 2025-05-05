import { useState, useCallback } from "react";

export const useTikTok = (tiktokUrl?: string) => {
  const [videoId, setVideoId] = useState<string | null>(null);
  const [thumbnailUrl, setThumbnailUrl] = useState<string | null>(null);

  const extractVideoId = (url: string) => {
    const match = url.match(/\/video\/(\d+)/);
    return match ? match[1] : null;
  };

  const loadThumbnail = useCallback(async () => {
    if (!tiktokUrl) return;
    const videoId = extractVideoId(tiktokUrl);
    setVideoId(videoId);

    try {
      const response = await fetch(
        `https://www.tiktok.com/oembed?url=${encodeURIComponent(tiktokUrl)}`
      );
      if (!response.ok) throw new Error("Failed to fetch TikTok oEmbed");
      const data = await response.json();
      setThumbnailUrl(data.thumbnail_url);
    } catch (error) {
      console.error("TikTok thumbnail load failed:", error);
    }
  }, [tiktokUrl]);

  return {
    videoId,
    thumbnailUrl,
    loadThumbnail,
  };
};

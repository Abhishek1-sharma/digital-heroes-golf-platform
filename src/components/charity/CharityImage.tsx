import React, { useState } from "react";

type CharityImageProps = {
  src?: string | null;
  alt: string;
  className?: string;
};

/** Renders a branded local image whenever a charity has no valid remote image. */
const CharityImage: React.FC<CharityImageProps> = ({ src, alt, className }) => {
  const fallback = "/images/charity-fallback.svg";
  const [imageSrc, setImageSrc] = useState(src || fallback);

  return (
    <img
      src={imageSrc}
      alt={alt}
      className={className}
      onError={() => setImageSrc(fallback)}
    />
  );
};

export default CharityImage;

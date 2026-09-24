import React from "react";
import { Link } from "react-router-dom";
import { Globe, Share2 } from "lucide-react";

const Footer: React.FC = () => {
  return (
    <footer className="w-full bg-surface-container-lowest border-t border-primary/10">
      <div className="max-w-[1920px] mx-auto grid grid-cols-1 md:grid-cols-1 gap-16 px-6 md:px-24 py-20">
        <div className="lg:col-span-2">
          <div className="flex items-center gap-3 mb-8">
            <div className="w-10 h-10 bg-secondary rounded-lg flex items-center justify-center">
              <Globe className="w-6 h-6 text-on-secondary" />
            </div>
            <span className="text-xl font-display font-black tracking-tight uppercase">
              Play Golf
            </span>
          </div>
          <p className="font-sans text-sm tracking-wide text-on-surface-variant mb-10 leading-relaxed max-w-sm">
            A score-tracking and prize platform where every membership leaves a
            measurable mark for a cause you choose.
          </p>
          <div className="flex gap-6">
            <a
              href="#"
              className="w-10 h-10 rounded-full bg-surface-container-low border border-white/5 flex items-center justify-center hover:bg-primary/10 hover:text-primary transition-all"
            >
              <Share2 className="w-4 h-4" />
            </a>
            <a
              href="#"
              className="w-10 h-10 rounded-full bg-surface-container-low border border-white/5 flex items-center justify-center hover:bg-primary/10 hover:text-primary transition-all"
            >
              <Globe className="w-4 h-4" />
            </a>
          </div>
        </div>

        <div className="flex flex-col gap-6">
          <h6 className="text-on-surface font-display font-bold text-[10px] uppercase tracking-[0.2em] mb-4">
            Platform
          </h6>
          <Link
            className="font-sans text-sm text-on-surface-variant hover:text-primary transition-colors"
            to="/how-it-works"
          >
            How it Works
          </Link>
          <Link
            className="font-sans text-sm text-on-surface-variant hover:text-primary transition-colors"
            to="/charities"
          >
            Charities
          </Link>
          <Link
            className="font-sans text-sm text-on-surface-variant hover:text-primary transition-colors"
            to="/dashboard"
          >
            Dashboard
          </Link>
        </div>
      </div>

      <div className="max-w-[1920px] mx-auto px-6 md:px-24 py-12 border-t border-white/5 flex flex-col md:flex-row justify-between items-center gap-6">
        <p className="font-sans text-[10px] font-bold uppercase tracking-[0.2em] text-on-surface-variant">
          © 2026 Play Golf. ALL RIGHTS RESERVED.
        </p>
        <div className="flex gap-10">
          <span className="font-sans text-[10px] font-bold uppercase tracking-[0.2em] text-on-surface-variant hover:text-primary cursor-pointer transition-colors">
            United Kingdom
          </span>
          <span className="font-sans text-[10px] font-bold uppercase tracking-[0.2em] text-on-surface-variant hover:text-primary cursor-pointer transition-colors">
            English
          </span>
        </div>
      </div>
    </footer>
  );
};

export default Footer;

import birdVisionLogo from "../assets/birdvision-logo.png";
import "./SplashScreen.css";

function SplashScreen() {
  return (
    <div className="splash-screen">
      <div className="splash-center">
        <div className="splash-logo">
          <img
            src={birdVisionLogo}
            alt="Logo BirdVision IA"
          />
        </div>

        <h1 className="splash-title">
          BirdVision <span>IA</span>
        </h1>
      </div>
    </div>
  );
}

export default SplashScreen;
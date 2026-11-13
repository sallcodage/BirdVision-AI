
import "./Home.css";
import birdVisionLogo from "../assets/birdvision-logo.png";
import loginBackground from "../assets/login-background.png";
import siribraLogo from "../assets/siribra-logo.png";

function Home({ onLogin, onRegister }) {
  const features = [
    {
      icon: "◎",
      title: "Détection intelligente",
      description:
        "Détectez automatiquement les oiseaux présents dans vos photographies grâce à la vision par ordinateur.",
    },
    {
      icon: "▦",
      title: "Comptage automatique",
      description:
        "Obtenez le nombre d'oiseaux détectés dans chaque image analysée.",
    },
    {
      icon: "◈",
      title: "Plusieurs modèles IA",
      description:
        "Comparez les analyses de RT-DETR-X, YOLO26s et D-FINE-X.",
    },
    {
      icon: "◉",
      title: "Résultats visuels",
      description:
        "Visualisez les oiseaux détectés sur une image annotée et consultez les résultats.",
    },
    {
      icon: "≋",
      title: "Seuil de confiance",
      description:
        "Personnalisez la sensibilité de la détection selon les besoins de votre analyse.",
    },
    {
      icon: "▥",
      title: "Statistiques détaillées",
      description:
        "Consultez le nombre de détections et les scores de confiance des résultats.",
    },
  ];

  const steps = [
    {
      number: "01",
      title: "Importer une image",
      description:
        "Sélectionnez une photographie au format JPG, JPEG ou PNG.",
    },
    {
      number: "02",
      title: "Choisir un modèle",
      description:
        "Sélectionnez RT-DETR-X, YOLO26s ou D-FINE-X et réglez le seuil de confiance.",
    },
    {
      number: "03",
      title: "Lancer l'analyse",
      description:
        "L'intelligence artificielle recherche automatiquement les oiseaux.",
    },
    {
      number: "04",
      title: "Consulter les résultats",
      description:
        "Découvrez l'image annotée, le comptage et les statistiques.",
    },
  ];

  return (
    <div className="home-page" id="accueil">
      {/* HEADER */}
      <header className="home-header">
        <div className="home-nav-container">
          <a href="#accueil" className="home-brand">
            <img
              src={birdVisionLogo}
              alt="Logo BirdVision IA"
            />
            <span>
              BirdVision <strong>IA</strong>
            </span>
          </a>

          <nav className="home-nav-links" aria-label="Navigation principale">
            <a href="#accueil">Accueil</a>
            <a href="#fonctionnalites">Fonctionnalités</a>
            <a href="#fonctionnement">Comment ça marche ?</a>
            <a href="#technologies">Technologies</a>
            <a href="#apropos">À propos</a>
          </nav>

          <div className="home-nav-actions">
            <button
              type="button"
              className="home-login-btn"
              onClick={onLogin}
            >
              Connexion
            </button>

            <button
              type="button"
              className="home-register-btn"
              onClick={onRegister}
            >
              S'inscrire
            </button>
          </div>
        </div>
      </header>

      {/* HERO */}
      <section
        className="home-hero"
        style={{
          backgroundImage: `linear-gradient(
            90deg,
            rgba(2, 14, 25, 0.94),
            rgba(3, 31, 50, 0.72),
            rgba(3, 31, 50, 0.35)
          ), url(${loginBackground})`,
        }}
      >
        <div className="home-hero-content">
          <div className="home-hero-badge">
            INTELLIGENCE ARTIFICIELLE & BIODIVERSITÉ
          </div>

          <h1>
            Explorez le monde des oiseaux
            <span> grâce à l'intelligence artificielle.</span>
          </h1>

          <p>
            BirdVision IA est une plateforme intelligente
            de détection et de comptage des oiseaux.
            Importez vos photographies, choisissez votre
            modèle de vision par ordinateur et obtenez
            des résultats visuels et statistiques.
          </p>

          <div className="home-hero-buttons">
            <button
              type="button"
              className="home-primary-btn"
              onClick={onRegister}
            >
              Commencer gratuitement →
            </button>

            <a
              href="#fonctionnalites"
              className="home-outline-btn"
            >
              Découvrir la plateforme
            </a>
          </div>

          <div className="home-hero-highlights">
            <span>Détection d'oiseaux</span>
            <span>Comptage automatique</span>
            <span>3 modèles IA</span>
          </div>
        </div>
      </section>

      {/* FONCTIONNALITÉS */}
      <section
        className="home-section"
        id="fonctionnalites"
      >
        <div className="home-section-heading">
          <span className="home-section-kicker">
            NOS FONCTIONNALITÉS
          </span>

          <h2>
            Une plateforme conçue pour
            <span> l'analyse intelligente des oiseaux</span>
          </h2>

          <p>
            Découvrez les outils disponibles dans BirdVision IA
            pour analyser vos images facilement.
          </p>
        </div>

        <div className="home-features-grid">
          {features.map((feature) => (
            <article
              className="home-feature-card"
              key={feature.title}
            >
              <div className="home-feature-icon">
                {feature.icon}
              </div>

              <h3>{feature.title}</h3>
              <p>{feature.description}</p>
            </article>
          ))}
        </div>
      </section>

      {/* COMMENT ÇA MARCHE */}
      <section
        className="home-section home-steps-section"
        id="fonctionnement"
      >
        <div className="home-section-heading">
          <span className="home-section-kicker">
            UTILISATION
          </span>

          <h2>
            Comment fonctionne <span>BirdVision IA ?</span>
          </h2>

          <p>
            Réalisez une analyse en quatre étapes simples.
          </p>
        </div>

        <div className="home-steps-grid">
          {steps.map((step) => (
            <article
              className="home-step-card"
              key={step.number}
            >
              <span className="home-step-number">
                {step.number}
              </span>

              <h3>{step.title}</h3>
              <p>{step.description}</p>
            </article>
          ))}
        </div>
      </section>

      {/* TECHNOLOGIES */}
      <section
        className="home-section"
        id="technologies"
      >
        <div className="home-section-heading">
          <span className="home-section-kicker">
            TECHNOLOGIES
          </span>

          <h2>
            Des technologies au service
            <span> de la vision par ordinateur</span>
          </h2>

          <p>
            BirdVision IA associe plusieurs modèles de
            détection à une application web moderne.
          </p>
        </div>

        <div className="home-tech-grid">
          <article className="home-tech-card">
            <div className="home-tech-label">
              MODÈLE IA
            </div>
            <h3>RT-DETR-X</h3>
            <p>
              Modèle de détection d'objets basé sur
              une architecture Transformer.
            </p>
          </article>

          <article className="home-tech-card">
            <div className="home-tech-label">
              MODÈLE IA
            </div>
            <h3>YOLO26s</h3>
            <p>
              Modèle de la famille YOLO utilisé pour
              détecter et localiser les oiseaux.
            </p>
          </article>

          <article className="home-tech-card">
            <div className="home-tech-label">
              MODÈLE IA
            </div>
            <h3>D-FINE-X</h3>
            <p>
              Modèle de détection permettant
              d'analyser les objets présents dans les images.
            </p>
          </article>
        </div>

        <div className="home-stack">
          <span>React</span>
          <span>Django REST Framework</span>
          <span>Python</span>
          <span>Computer Vision</span>
        </div>
      </section>

      {/* À PROPOS */}
      <section
        className="home-section home-about-section"
        id="apropos"
      >
        <div className="home-about-content">
          <div>
            <span className="home-section-kicker">
              À PROPOS DU PROJET
            </span>

            <h2>
              L'intelligence artificielle
              <span> au service de l'observation des oiseaux</span>
            </h2>

            <p>
              BirdVision IA est un projet de vision par ordinateur
              dont l'objectif est de faciliter la détection
              et le comptage des oiseaux à partir de photographies.
            </p>

            <p>
              La plateforme permet d'expérimenter plusieurs
              modèles d'intelligence artificielle et de
              consulter leurs résultats d'analyse.
            </p>

            <button
              type="button"
              className="home-primary-btn"
              onClick={onRegister}
            >
              Rejoindre BirdVision IA →
            </button>
          </div>

          <div className="home-about-panel">
            <div className="home-about-icon">AI</div>

            <h3>BirdVision IA</h3>

            <p>
              Détection, localisation et comptage
              automatique des oiseaux.
            </p>

            <div className="home-about-tags">
              <span>Intelligence artificielle</span>
              <span>Analyse d'images</span>
              <span>Biodiversité</span>
            </div>
          </div>
        </div>
      </section>

      {/* APPEL À L'ACTION */}
      <section className="home-cta-section">
        <div className="home-cta-content">
          <h2>
            Prêt à découvrir BirdVision IA ?
          </h2>

          <p>
            Créez votre compte pour commencer
            à analyser vos images d'oiseaux.
          </p>

          <div className="home-hero-buttons">
            <button
              type="button"
              className="home-primary-btn"
              onClick={onRegister}
            >
              Créer mon compte →
            </button>

            <button
              type="button"
              className="home-outline-btn"
              onClick={onLogin}
            >
              Se connecter
            </button>
          </div>
        </div>
      </section>

      {/* FOOTER */}
      <footer className="home-footer">
        <div className="home-footer-grid">
          <div className="home-footer-brand">
            <div className="home-footer-logo">
              <img
                src={birdVisionLogo}
                alt="BirdVision IA"
              />

              <strong>
                BirdVision <span>IA</span>
              </strong>
            </div>

            <p>
              Plateforme intelligente de détection
              et de comptage des oiseaux grâce
              à la vision par ordinateur.
            </p>
          </div>

          <div className="home-footer-column">
            <h3>Navigation</h3>
            <a href="#accueil">Accueil</a>
            <a href="#fonctionnalites">Fonctionnalités</a>
            <a href="#fonctionnement">Fonctionnement</a>
            <a href="#apropos">À propos</a>
          </div>

          <div className="home-footer-column">
            <h3>Technologies</h3>
            <a href="#technologies">RT-DETR-X</a>
            <a href="#technologies">YOLO26s</a>
            <a href="#technologies">D-FINE-X</a>
            <a href="#technologies">Django REST</a>
          </div>

          <div className="home-footer-column">
            <h3>Mon compte</h3>
            <button type="button" onClick={onLogin}>
              Connexion
            </button>
            <button type="button" onClick={onRegister}>
              Inscription
            </button>
          </div>
        </div>

        
<div className="home-footer-company">
  <img
    src={siribraLogo}
    alt="Logo SIRIBRA GROUP"
    className="home-siribra-logo"
  />

  <div className="home-footer-company-text">
    <strong>SIRIBRA GROUP</strong>
    <span>TECHNOLOGIE. VISION. IMPACT.</span>
    <p>Entreprise porteuse du projet BirdVision IA</p>
  </div>
</div>

      </footer>
    </div>
  );
}

export default Home;

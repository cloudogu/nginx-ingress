# Leitfaden für Entwickler

Diese Dokumentation enthält alle Informationen, die für die Entwicklung des Nginx-Ingress Dogu erforderlich sind.

## Voraussetzungen

1. Ein laufendes K8s-EcoSystem ist erforderlich, um den Nginx-Ingress Dogu zu entwickeln. Für weitere Informationen über die
   Einrichtung des K8s-EcoSystems siehe ...(TODO Link zur K8s-EcoSystem Einrichtung hinzufügen)

1. Ein SSL-Zertifikat sollte im K8s-EcoSystem vorhanden sein. Dieses sollte als ein Geheimnis namens
   `ecosystem/ecosystem-certificate` im K8s-EcoSystem zugänglich sein.

## Übersicht über die verfügbaren Make-Targets

Dieses Projekt stellt ein Make-Target namens `help` zur Verfügung, das alle verfügbaren Targets und deren Beschreibung ausgibt.

## Bauen und Bereitstellen der Dogu

Das Makefile enthält ein Ziel `build`, das folgendes tut:

1. Erzeugt das Dogu-Image.
1. Importiert das Image in alle K8s-EcoSystem-Knoten.
1. Wendet alle K8s-Ressourcen aus dem Ordner "k8s" an, einschließlich eines Deployments und eines Dienstes für die Dogu.

Das K8s-EcoSystem sollte nun automatisch einen Pod für das Dogu starten.
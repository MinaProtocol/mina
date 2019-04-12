let message = __MODULE__;
type mainToRendererMessages = [ | `Deep_link(Route.t)];

type rendererToMainMessages = [ | `HelloBack];

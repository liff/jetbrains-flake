package updater

import org.http4s.implicits._
import org.http4s.Uri
import cats.syntax.all._

import Edition._, Status._, Distribution._

val updates = uri"https://www.jetbrains.com/updates/updates.xml"

val downloadSite = uri"https://download.jetbrains.com"

val downloadPaths = Map(
  "CLion" -> "cpp",
  "DataGrip" -> "datagrip",
  "GoLand" -> "go",
  "IntelliJ IDEA" -> "idea",
  "PhpStorm" -> "webide",
  "PyCharm" -> "python",
  "RubyMine" -> "ruby",
  "WebStorm" -> "webstorm",
)

val packagePrefix: PartialFunction[(String, Edition), String] =
  case ("CLion", Licensed) => "CLion"
  case ("DataGrip", Licensed) => "datagrip"
  case ("GoLand", Licensed) => "goland"
  case ("IntelliJ IDEA", Licensed) => "ideaIU"
  case ("IntelliJ IDEA", Community) => "ideaIC"
  case ("PhpStorm", Licensed) => "PhpStorm"
  case ("PyCharm", Licensed) => "pycharm-professional"
  case ("PyCharm", Community) => "pycharm-community"
  case ("RubyMine", Licensed) => "RubyMine"
  case ("WebStorm", Licensed) => "WebStorm"

def downloadUriFor(product: String, edition: Edition, status: Status, distribution: Distribution, build: Build): Option[Uri] =
  (downloadPaths.get(product), packagePrefix.lift((product, edition))).mapN { (path, prefix) =>
    val version = status.match
      case Release => build.version
      case Eap => build.fullNumber.getOrElse(build.number)
    val vary = distribution.match
      case Default => ""
      case NoJbr => "-no-jbr"
    downloadSite / path / s"$prefix-$version$vary.tar.gz"
  }

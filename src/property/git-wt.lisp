;;; Consfigurator -- Lisp declarative configuration management system

;;; Copyright (C) 2026  Thijs Oppermann <thijso@gmail.com>

;;; This file is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3, or (at your option)
;;; any later version.

;;; This file is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.

;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

(in-package :consfigurator.property.git-wt)
(named-readtables:in-readtable :consfigurator)

(defprop %bare-snapshot-extracted :posix
    (snapshot-name directory
               &aux (dest
                     (merge-pathnames ".git"
                                      (ensure-directory-pathname directory))))
  "Extract a tarball as produced by DATA:GIT-WT-SNAPSHOT under DIRECTORY."
  (:desc (declare (ignore dest))
         #?"git bare wt snapshot ${snapshot-name} extracted")
  (:hostattrs (declare (ignore dest))
              (require-data "--git-wt-snapshot" snapshot-name))
  (:check (and (remote-exists-p dest)))
  (:apply
   (file:directory-exists dest)
   (informat t "~&%bare-snapshot-extracted apply: ~a" dest)
   (with-remote-current-directory (dest)
     (mrun :input (get-data-stream "--git-wt-snapshot" snapshot-name)
           "tar" (if (zerop (get-connattr :remote-uid)) "oxfz" "xfz") "-"))
   (with-remote-current-directory (directory)
     (mrun "git" "config" "--bool" "core.bare" "true")
     (mrun "git" "config" "remote.origin.fetch" "+refs/heads/*:refs/remotes/origin/*")
     ;; (mrun "git" "fetch" "origin")  -> not possible without ssh key
     )))

(defproplist initialized :posix (snapshot-name dest)
  "Setup a worktree git repo based on SNAPSHOT-NAME produced by
DATA:GIT-WT-SNAPSHOT at DEST."
  (:desc #?"${snapshot-name} initialized at ${dest}")
  (git:installed)
  (%bare-snapshot-extracted snapshot-name dest))

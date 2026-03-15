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

(in-package :consfigurator.data.git-wt-snapshot)
(named-readtables:in-readtable :consfigurator)

(defmethod register-data-source ((type (eql :git-wt-snapshot))
                                 &key name repo)
  "Provide tarball snapshots of a local git repository specifically
meant to be used as a bare repository base for a git worktree setup.
Provides prerequisite data identified by \"--git-wt-snapshot\", \"NAME\".

Rather than using git-bundle(1) or git-archive(1), we tar up the .git
directory and use that for the bare copy on remote.  That way, it's still a
git repo on the remote side, but we don't require git to be installed on the
remote side to get a copy of the bare repo over there.

Be aware that for this to work, this tarred repo needs to be initialized by
GIT-WT:INITIALIZE.  See there for details."
  (when (data-source-providing-p "--git-wt-snapshot" name)
    (simple-program-error
     "Another data source is providing git snapshots identified by ~S." name))
  (with-current-directory (repo)
    (unless (zerop (nth-value 2 (run-program '("git" "rev-parse" "--git-dir")
                                             :ignore-error-status t)))
      (missing-data-source "~A is not a git repository." repo)))
  (let* ((cached
           (get-highest-local-cached-prerequisite-data "--git-wt-snapshot" name))
         (cached-commit (and cached (nth 1 (split-string (data-version cached)
                                                         :separator ".")))))

    (when cached
      (setf (data-mime cached) "application/gzip"))
    (labels ((latest-version (tip)
               (format nil "~A.~A" (get-universal-time) tip))
             (check (iden1 iden2)
               (and (string= iden1 "--git-wt-snapshot")
                    (string= iden2 name)
                    (let ((tip (get-tip repo)))
                      (if (and cached-commit (string= cached-commit tip))
                          (data-version cached)
                          (latest-version tip)))))
             (extract (&rest ignore)
               (declare (ignore ignore))
               (let* ((tip (get-tip repo))
                      (version (latest-version tip))
                      (path (local-data-pathname
                             "--git-wt-snapshot" name version)))
                 (if (and cached-commit (string= cached-commit tip))
                     cached
                     (progn
                       (ignore-errors
                        (mapc #'delete-file
                              (directory-files
                               (pathname-directory-pathname path))))
                       (make-snapshot name repo path)
                       (setq cached-commit tip
                             cached (make-instance 'file-data
                                                   :file path
                                                   :mime "application/gzip"
                                                   :iden1 "--git-wt-snapshot"
                                                   :iden2 name
                                                   :version version)))))))
      (cons #'check #'extract))))

(defun make-snapshot (name repo output)
  (let ((repo-git-dir (strcat (namestring repo) ".git/")))
    (with-current-directory (repo-git-dir)
      (run-program '("git" "gc"))
      (run-program
       `("tar" "cfz" ,(namestring output) "./")))))

(defun get-tip (repo)
  "Fake the tip as it doesn't really matter."
  (with-current-directory (repo)
    (stripln
     (run-program '("git" "rev-parse" "--verify" "HEAD")
                  :output :string))))

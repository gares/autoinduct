Require Import Ltac2.Ltac2.

(* stdlib fail does enter so has type unit (indeed it doesn't fail if
   there are no focused goals) *)
Ltac2 fail s := Control.backtrack_tactic_failure s.

(* If you don't want to use Unsafe.kind, but can only handle fixpoints with 2 arguments *)
Ltac2 dumb_struct_arg f :=
  lazy_match! f with
  (* `fix f n m {struct n} := bla` and `fix f n {struct n} := fun m => bla` are the same thing so this handles both arity 1 and arity 2 when the first argument is the structural argument *)
  | (fix f n {struct n} := _) => 0
  | (fix f n m {struct m} := _) => 1
  end.

Ltac2 rec struct_arg f :=
  match Constr.Unsafe.kind f with
  | Constr.Unsafe.Fix structs which _ _ => Array.get structs which
  | Constr.Unsafe.Lambda _ body => Int.add 1 (struct_arg body)
  | _ => fail "not a fixpoint"
  end.

Ltac2 find_applied f :=
  match! goal with
  | [ |- context [ ?t ] ] =>
      match Constr.Unsafe.kind t with
      | Constr.Unsafe.App g args =>
          let farg :=
            match f with
            | Some (f,farg) =>
                if Constr.equal f g then farg
                else fail "applies a different function"
            | None =>
                if Constr.is_const g then struct_arg (eval red in $g)
                else fail "not a constant"
            end
          in
          if Int.le farg (Array.length args)
          then Array.get args farg
          else fail "not applied enough"
      | _ => fail "not an application"
      end
  end.

(* might want to call this in find_reducible_apply so match goal will backtrack *)

Ltac2 autoinduct0 f :=
  let f := Option.map (fun f => (f, struct_arg (eval red in $f))) f in
  let arg := find_applied f in
  induction $arg.

Ltac2 Notation "autoinduct" f(constr) := (autoinduct0 (Some f)).

Ltac2 Notation "autoinduct" := (autoinduct0 None).

Goal forall n, n + 0 = n.
  intros.
  Succeed (autoinduct;simpl;ltac1:(congruence)).
  autoinduct Nat.add;simpl;ltac1:(congruence).
Qed.

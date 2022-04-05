Require Import Lra Lia Interval.Tactic.
Import Raux.
Require Import Flocq.IEEE754.Binary.
Require Import Setoid.

Import List ListNotations.
Import Tree. (* must import this _after_ List *)
Import Interval Private Interval_helper I2 IT2.IH I2.T Xreal Interval.Eval.Reify.

Import Basic.
Import Bool.

Set Bullet Behavior "Strict Subproofs".
Locate R.

Definition expr_equiv (a b: expr) : Prop :=
  forall env, eval a env = eval b env.

 Infix "==" := expr_equiv (at level 70, no associativity).

Lemma expr_equiv_refl: forall e, e == e.
Proof. intros ? ?; reflexivity. Qed.

Lemma expr_equiv_sym: forall e1 e2, e1 == e2 -> e2 == e1.
Proof. intros ? ? ? ?; congruence. Qed.

Lemma expr_equiv_trans: forall e1 e2 e3, e1 == e2 -> e2 == e3 -> e1 == e3.
Proof. intros; intros ?; congruence. Qed.

Add Parametric Relation : expr expr_equiv
  reflexivity proved by expr_equiv_refl
  symmetry proved by expr_equiv_sym
  transitivity proved by expr_equiv_trans
  as expr_equiv_rel.

Add Parametric Morphism : Eunary
  with signature eq ==> expr_equiv ==> expr_equiv
  as Eunary_mor.
Proof.
intros. intro. simpl. rewrite H; auto.
Qed.


Add Parametric Morphism : Ebinary
  with signature eq ==> expr_equiv ==> expr_equiv ==> expr_equiv
  as Ebinary_mor.
Proof.
intros. intro. simpl. rewrite H, H0; auto.
Qed.

Open Scope R_scope.

Definition nullary_op_nonzero (n: nullary_op) : bool :=
 match n with
 | Int 0 => false
 | Bpow 0 _ => false
 | Bpow (Zneg _) _ => false
 | _ => true
 end.

Fixpoint ring_simp_Mul fuel (e1 e2 : expr) : option expr :=
  match fuel with O => None
  | S fuel' =>
     match e1, e2 with
     | Econst (Int 1), _ =>
                Some e2
     | _, Econst (Int 1) =>
                Some e1
     | Econst (Bpow 1 0), _ =>
                Some e2
     | _, Econst (Bpow 1 0) =>
                Some e1
     | Econst (Int 0), _ =>
                Some e1
     | _, Econst (Int 0) =>
                Some e2
     | Econst (Int a), Econst (Int b) => Some (Econst (Int (a*b)))
     | Eunary Inv (Econst a), Eunary Inv (Econst b) => 
        if nullary_op_nonzero a && nullary_op_nonzero b then
         match ring_simp_Mul fuel' (Econst a) (Econst b) with
         | Some ab => Some (Eunary Inv ab)
         | None => Some (Eunary Inv (Ebinary Mul (Econst a) (Econst b)))
         end
       else None
     | Eunary Inv (Econst _), Econst _ => 
         Some (Ebinary Mul e2 e1)
     | Econst _, Ebinary Mul (Eunary Inv (Econst a)) (Eunary Inv (Econst b)) =>
        if nullary_op_nonzero a && nullary_op_nonzero b then
         match ring_simp_Mul fuel' (Econst a) (Econst b) with
         | Some ab => Some (Ebinary Mul e1 (Eunary Inv ab))
         | None => Some (Ebinary Mul e1 (Eunary Inv (Ebinary Mul (Econst a) (Econst b))))
         end
         else None
     | Eunary Inv (Econst _), Ebinary Mul (Eunary Inv (Econst b)) c =>
         match ring_simp_Mul fuel' e1 (Eunary Inv (Econst b)) with
         | Some ab => match ring_simp_Mul fuel' ab c with
                               | Some abc => Some abc
                               | None => Some (Ebinary Mul ab c)
                               end
         | None => None
        end
     | Econst _, Ebinary Mul (Econst _) (Econst _) => None
     | Econst _, Econst _ => None
     | Econst _, Eunary Inv (Econst _) => None
     | _, Econst _ =>  ring_simp_Mul fuel' e2 e1
     | _, Eunary Inv (Econst _) =>  ring_simp_Mul fuel' e2 e1
     | _, Ebinary Mul (Econst b) c => 
          match ring_simp_Mul fuel' e1 (Econst b) with
          | Some ab => Some (Ebinary Mul ab c)
          | None => Some (Ebinary Mul (Ebinary Mul e1 (Econst b)) c)
          end
     | _, Ebinary Mul (Eunary Inv (Econst b)) c => 
          match ring_simp_Mul fuel' e1  (Eunary Inv (Econst b)) with
          | Some ab => Some (Ebinary Mul ab c)
          | None => Some (Ebinary Mul (Ebinary Mul e1  (Eunary Inv (Econst b))) c)
          end
     | Ebinary Add e11 e12, Ebinary Add e21 e22 =>
          Some (Ebinary Add 
                (Ebinary Add (Ebinary Mul e11 e21) (Ebinary Mul e11 e22))
                (Ebinary Add (Ebinary Mul e12 e21) (Ebinary Mul e12 e22)))
     | Ebinary Add e11 e12, Ebinary Sub e21 e22 =>
          Some (Ebinary Add 
                (Ebinary Sub (Ebinary Mul e11 e21) (Ebinary Mul e11 e22))
                (Ebinary Sub (Ebinary Mul e12 e21) (Ebinary Mul e12 e22)))
     | Ebinary Add e11 e12,  _ =>
           Some (Ebinary Add (Ebinary Mul e11 e2) (Ebinary Mul e12 e2))
     | Ebinary Sub e11 e12, Ebinary Add e21 e22 =>
          Some (Ebinary Sub 
                (Ebinary Add (Ebinary Mul e11 e21) (Ebinary Mul e11 e22))
                (Ebinary Add (Ebinary Mul e12 e21) (Ebinary Mul e12 e22)))
     | Ebinary Sub e11 e12, Ebinary Sub e21 e22 =>
          Some (Ebinary Sub
                (Ebinary Sub (Ebinary Mul e11 e21) (Ebinary Mul e11 e22))
                (Ebinary Sub (Ebinary Mul e12 e21) (Ebinary Mul e12 e22)))
     | Ebinary Sub e11 e12,  _ =>
           Some (Ebinary Sub (Ebinary Mul e11 e2) (Ebinary Mul e12 e2))
     | _, Ebinary Add e21 e22 =>
           Some (Ebinary Add (Ebinary Mul e1 e21) (Ebinary Mul e1 e22))
     | _, Ebinary Sub e21 e22 =>
           Some (Ebinary Sub (Ebinary Mul e1 e21) (Ebinary Mul e1 e22))
     | _, _ => None
     end
  end.

Definition zeroexpr := Econst (Int 0).
Definition oneexpr := Econst (Int 1).
Definition moneexpr := Econst (Int (-1)).
Definition infinity := PrimFloat.infinity.

Lemma nullary_op_nonzero_e:
 forall n, nullary_op_nonzero n = true -> nullary_real n <> 0.
Proof.
destruct n; simpl; intros; auto.
destruct n; try discriminate; auto.
apply not_0_IZR. lia.
destruct r; try discriminate.
clear. induction n; simpl; try lra.
apply not_0_IZR. lia.
apply Rinv_neq_0_compat.
apply not_0_IZR. lia.
pose proof Rgt_2PI_0; lra.
Qed.

Local Lemma Some_inj: forall {A} (x y: A), Some x = Some y -> x=y.
Proof. congruence. Qed.

Lemma ring_simp_Mul_correct:
  forall fuel e1 e2 e, 
    ring_simp_Mul fuel e1 e2 = Some e ->
    e == Ebinary Mul e1 e2.
Proof.
induction fuel; simpl; intros.
discriminate.
symmetry.
destruct e1, e2; simpl in *; try discriminate;
repeat
 match goal with
| H: ring_simp_Mul _ _ _ = _ |- _ => apply IHfuel in H
| H: Some _ = Some _ |- _ => apply Some_inj in H; subst
| H: None = _ |- _ => discriminate H
| H: ?a == ?b |- _ => is_var a; rewrite H; clear H
| H: match ?x with _ => _ end = _ |- _ => is_var x; destruct x
| H: match ?x with _ => _ end = _ |- _ => destruct x eqn:?H
| H: _ && _ = true |- _ => rewrite andb_true_iff in H; destruct H
| H: nullary_op_nonzero _ = true |- _ => apply nullary_op_nonzero_e in H
 end;
 intro; simpl; 
 try ring;
 rewrite <- ?mult_IZR, ?Zpow_facts.Zpower_pos_0_l; simpl; auto;
 try (rewrite <- Rinv_mult_distr by auto; auto).
Qed.


Definition add_assoc2 (enable: bool) op e1 e2 :=
 match op, e2 with
 | Add, Econst (Int 0) => Some e1
 | Sub, Econst (Int 0) => Some e1
 | Sub, Ebinary Mul (Econst (Int (Zneg p))) b =>
                Some (Ebinary Add e1 (Ebinary Mul (Econst (Int (Zpos p))) b))
 | Sub, Eunary Neg b => Some (Ebinary Add e1 b)
 | Add, Ebinary Add e21 e22 => 
        if enable then Some (Ebinary Add (Ebinary Add e1 e21) e22) else None
 | Add, Ebinary Sub e21 e22 =>
        if enable then Some (Ebinary Sub (Ebinary Add e1 e21) e22) else None
 | Sub, Ebinary Add e21 e22 =>
        if enable then Some (Ebinary Sub (Ebinary Sub e1 e21) e22) else None
 | Sub, Ebinary Sub e21 e22 =>
        if enable then Some (Ebinary Add (Ebinary Sub e1 e21) e22) else None
 | _, _ => None
 end.

Definition add_assoc (enable: bool) op e1 e2 :=
 match op, e1 with
 | Add, Econst (Int 0) => Some e2
 | Sub, Econst (Int 0) => Some (Eunary Neg e2)
 | _, _ => add_assoc2 enable op e1 e2
 end.

Lemma add_assoc_correct: 
  forall enable op e1 e2 e,
  add_assoc enable op e1 e2 = Some e ->
  e == Ebinary op e1 e2.
Proof.
intros.
unfold add_assoc, add_assoc2 in H.
destruct op; simpl; auto; try discriminate;
destruct e1, e2; simpl;  try discriminate; auto;
repeat match goal with
           | H: Some _ = Some _ |- _ => inversion H; clear H; subst
           | H: context [match ?a with _ => _ end] |- _  => 
               is_var a; destruct a; simpl in H; try discriminate; auto 
           end;
intro; simpl; rewrite ?IZR_NEG; ring.
Qed.

Definition add_assoc' enable op e1 e2 :=
 match add_assoc enable op e1 e2 with Some e => e | None => Ebinary op e1 e2 end.

Lemma add_assoc'_correct:
 forall enable op e1 e2, add_assoc' enable op e1 e2 == Ebinary op e1 e2.
Proof.
intros.
unfold add_assoc'.
destruct (add_assoc _ _ _ _) eqn:?H; auto.
eapply add_assoc_correct; eauto.
reflexivity.
Qed.

Definition mul_fuel := 30%nat.

Definition ring_simp_Div e1 e2 :=
 match e1, e2 with
 | Econst (Int 1), _ => Some (Eunary Inv e2)
 | _, Econst (Int 1) => Some e1
 | _, _ => None
 end.

Lemma ring_simp_Div_correct:
  forall e1 e2 e, 
    ring_simp_Div e1 e2 = Some e ->
    e == Ebinary Div e1 e2.
Proof.
unfold ring_simp_Div.
intros.
destruct e1,e2; intros; try discriminate;
repeat match type of H with match ?a with _ => _ end = _ => destruct a; try discriminate end;
apply Some_inj in H; subst;
intro; simpl; 
rewrite ?Rcomplements.Rdiv_1; auto;
unfold Rdiv;
rewrite Rmult_1_l;
auto.
Qed.

Fixpoint ring_simp1 enable (e: expr) :=
  (* If enable=true then use associativity of addition *)
 match e with
 | Evar _ => None
 | Econst _ => None
 | Eunary Neg e1 => Some (Ebinary Mul (Econst (Int (-1))) e1)
 | Eunary Sqr e1 => 
      match ring_simp1 enable e1 with
      | Some e1' => match ring_simp_Mul mul_fuel e1' e1' with
                             | Some e => Some e
                             | None => Some (Ebinary Mul e1' e1')
                             end
      | None => Some (Ebinary Mul e1 e1)
      end
 | Eunary op e1 => None
 | Ebinary op e1 e2 =>
    match op, ring_simp1 enable e1, ring_simp1 enable e2 with
    | Div, Some e1', Some e2' => ring_simp_Div e1' e2'
    | Div, Some e1', None => ring_simp_Div e1' e2
    | Div, None, Some e2' => ring_simp_Div e1 e2'
    | Div, None, None => ring_simp_Div e1 e2
    | Mul, None, None => ring_simp_Mul mul_fuel e1 e2
    | _, None, None => add_assoc enable op e1 e2
    | Mul, Some e1', None =>
            match ring_simp_Mul mul_fuel e1' e2 with
            | Some e => Some e
            | None => Some (Ebinary Mul e1' e2)
            end
    | Mul, None, Some e2' =>
            match ring_simp_Mul mul_fuel e1 e2' with
            | Some e => Some e
            | None => Some (Ebinary Mul e1 e2')
            end
    | _, Some e1', Some e2' => Some (add_assoc' enable op e1' e2')
    | _, Some e1', None => Some (add_assoc' enable op e1' e2)
    | _, None, Some e2' => Some (add_assoc' enable op e1 e2')
    end
 end.

Lemma ring_simp1_correct:
  forall enable e e', 
    ring_simp1 enable e = Some e' ->
    e == e'.
Proof.
Opaque mul_fuel.
Opaque add_assoc.
Opaque add_assoc'.
induction e; simpl; intros; try discriminate.
-
destruct (ring_simp1 enable e).
+ specialize (IHe _ (eq_refl _)).
  destruct u; try discriminate.
  * apply Some_inj in H; subst; intro; simpl; ring.
  * destruct (ring_simp_Mul mul_fuel e0 e0) eqn:?H; apply Some_inj in H.
     rewrite IHe, <- H.
    rewrite (ring_simp_Mul_correct _ _ _ _ H0). intro; reflexivity.
     rewrite IHe, <- H. intro; reflexivity.
+
 clear IHe.
 destruct u; try discriminate; apply Some_inj in H; rewrite <- H; intro; simpl.
  ring. reflexivity.
-
destruct b; auto;
destruct (ring_simp1 enable e1) eqn:?H; try discriminate H;
destruct (ring_simp1 enable e2) eqn:?H; try discriminate H;
try apply Some_inj in H;
rewrite ?(IHe1 _ (eq_refl _));
rewrite ?(IHe2 _ (eq_refl _));
clear IHe1 IHe2;
try match type of H with match ?a with _ => _ end = _ =>
   destruct a eqn:H2; apply Some_inj in H; subst; rename H2 into H
end;
try (apply add_assoc_correct in H; rewrite H; clear H);
try (rewrite <- H; clear H);
rewrite ?add_assoc'_correct,
           ?(ring_simp_Mul_correct _ _ _ _ H),
           ?(ring_simp_Div_correct _ _ _ H);
try reflexivity.
Transparent mul_fuel.
Transparent add_assoc.
Transparent add_assoc'.
Qed.

Fixpoint ring_simp enable n (e: expr) {struct n} : expr :=
 match n with
 | O => e
 | S n' => match ring_simp1 enable e with
               | Some e' => ring_simp enable n' e'
               | None => e
               end
 end.

Lemma ring_simp_correct:
  forall enable n e env, 
    eval e env = eval (ring_simp enable n e) env.
Proof.
induction n; simpl; intros; auto.
destruct (ring_simp1 enable e) eqn:?H; auto.
rewrite (ring_simp1_correct _ _ _ H).
auto.
Qed.

Ltac simple_reify :=
match goal with
 |- Rabs ?t <= ?r =>
  let vars := get_vars t (@nil R) in
  let expr1 := reify t vars in
  let expr := fresh "__expr" in 
  pose (expr := expr1);
  change t with (eval expr vars);
  find_hyps vars;
  let __vars := fresh "__vars" in set (__vars := vars) in *
end.

Ltac reified_ring_simplify enable e :=
 match goal with |- context [eval e ?vars] =>
   let H := fresh in let e1 := fresh e in
  assert (H :=ring_simp_correct enable 100 e vars);
  set (e1 := ring_simp enable 100 e) in H; 
  hnf in e1; cbv [add_assoc' add_assoc] in e1;
  rewrite H; clear H; try clear e
 end.

Ltac unfold_eval_hyps :=
 match goal with |- context [eval ?e _] => try unfold e; try clear e end;
 match goal with |- eval_hyps ?h ?v ?p =>
    try unfold h; try clear h;
    try unfold v; try clear v;
    try unfold p; try clear p
  end;
 cbv [eval_hyps eval_hyps_aux eval_hyp 
        add_assoc' add_assoc
        eval nullary_real unary_real binary_real]; 
  intros; simpl nth.

Definition fint := Float.f_interval F.type.

Definition decent_interval (f: fint) :=
 match f with
 | Float.Ibnd l u => F.real l && F.real u
 | _ => false
 end.

Fixpoint b_expr0 (e: expr) : fint :=
match e with
| Evar _ => Float.Inan
| Econst (Int n) => fromZ p52 n
| Econst (Bpow 2 n) => I.power_int p52 (fromZ p52 2) n
| Eunary Neg e' =>  neg (b_expr0 e')
| Eunary Abs e' => abs (b_expr0 e')
| Eunary Inv e' => let f := b_expr0 e' in
                            if decent_interval f then inv p52 (b_expr0 e') else Float.Inan
| Eunary (PowerInt i) e' => let f := b_expr0 e' in
                                        if decent_interval f then I.power_int p52 f i else Float.Inan
| Ebinary Mul e1 e2 => let f1 := b_expr0 e1 in let f2 := b_expr0 e2 in
                                      if decent_interval f1 && decent_interval f2 
                                      then mul p52 (b_expr0 e1) (b_expr0 e2)
                                      else Float.Inan
| _ => Float.Inan
end.

Lemma b_expr0_inv:
 forall l u x, 
    match (if F.real l && F.real u then Float.Ibnd l u else Float.Inan) with
      | Float.Inan => True
      | Float.Ibnd lo hi => F.toR lo <= x <= F.toR hi
      end ->
    contains (convert (div p52 (fromZ p52 1) (if F.real l && F.real u then Float.Ibnd l u else Float.Inan))) (Xreal (1 / x)).
Proof.
intros.
set (xx := if F.real l && F.real u then Float.Ibnd l u else Float.Inan) in *.
pose proof J.div_correct p52 (fromZ p52 1) xx 1 x.
match type of H0 with _ -> _ -> ?A => assert A; [apply H0 | ]; clear H0 end.
apply fromZ_correct.
subst xx.
destruct (F.real l) eqn:?H, (F.real u) eqn:?H; simpl in *; auto.
rewrite F'.valid_lb_real by auto.
rewrite F'.valid_ub_real by auto.
simpl.
rewrite F.real_correct in *.
unfold F.toR in *.
destruct (F.toX l) eqn:?H; try discriminate.
destruct (F.toX u) eqn:?H; try discriminate.
simpl in *. auto.
clear - H1.
subst xx.
red in H1.
simpl in H1.
auto.
Qed.

Definition fixup_fint (x: fint) : fint :=
 match x with
 | Float.Ibnd lo hi => if F.real lo && F.real hi then x else Float.Inan 
 | _ => x
 end.

Lemma classify_neg:
 forall l, F.classify (F.neg l) = 
          match F.classify l with
          | Sig.Fminfty => Sig.Fpinfty
          | Sig.Fpinfty => Sig.Fminfty
          | c => c
          end.
Proof.
intros.
pose proof (F.neg_correct l).
destruct (F.classify l) eqn:?H; auto.
unfold F.toX in H.
pose proof (F.classify_correct l).
pose proof (F.classify_correct (F.neg l)).
rewrite F'.real_neg in H2.
rewrite H1 in H2; clear H1.
rewrite H0 in H2.
destruct (F.classify (F.neg l)); auto; discriminate.
Qed.

Lemma toX_Xreal_real:
 forall x y, F.toX x = Xreal y -> F.real x = true.
Proof.
intros.
unfold F.real.
unfold F.toX, FtoX, F.toF in *.
rewrite FloatAxioms.classify_spec.
destruct (FloatOps.Prim2SF x); try destruct s; auto; inversion H; clear H; subst; simpl; auto;
destruct (match SpecFloat.digits2_pos m with
      | 53%positive => true
      | _ => false
      end); auto.
Qed.

Lemma toR_neg:
 forall u, F.real u = true -> F.toR (F.neg u) = - (F.toR u).
Proof.
intros.
unfold F.toR.
unfold proj_val.
rewrite I2.F'.neg_correct.
destruct (F.toX u); simpl; auto.
lra.
Qed.

Lemma inv_div1:
  forall x, 
   decent_interval x = true -> 
   inv p52 x = div p52 (fromZ p52 1) x.
Proof.
intros.
unfold inv, div.
change (fromZ p52 1) with (Float.Ibnd I.c1 I.c1).
cbv iota.
change (sign_strict_ I.c1 I.c1) with Xgt.
destruct x; auto.
simpl in H. rewrite andb_true_iff in H. destruct H.
unfold Fdivz_DN, Fdivz_UP.
rewrite H, H0.
auto.
Qed.

Lemma fixup_fint_abs_correct:
 forall l u x, 
  match fixup_fint (Float.Ibnd l u) with
  | Float.Inan => True
  | Float.Ibnd lo hi => F.toR lo <= x <= F.toR hi
  end ->
 match fixup_fint (abs (Float.Ibnd l u)) with
 | Float.Inan => True
 | Float.Ibnd lo hi => F.toR lo <= unary_real Abs x <= F.toR hi
 end.
Proof.
intros.
simpl in H.
unfold unary_real.
simpl in *. unfold sign_large_.
rewrite (F.classify_correct l), (F.classify_correct u) in H.
rewrite (F.cmp_correct l F.zero), (F.cmp_correct u F.zero).
rewrite F'.classify_zero.
destruct (F.classify l) eqn:Hl,  (F.classify u) eqn:Hu; simpl in H;
try solve [
  simpl;
  try (destruct (Xcmp _ _); simpl);
  rewrite ?F'.real_neg,
   ?(F.classify_correct l), ?Hl,
   ?(F.classify_correct u), ?Hu; simpl; auto;
match goal with |- context [F.real (F.max ?a ?b)] =>
  let HM := fresh "HM" in assert (HM := F.max_correct a b);
  rewrite ?classify_neg, ?Hl, ?Hu in HM;
  rewrite F.classify_correct, HM; simpl; auto
end].
unfold Xcmp.
destruct (F.toX l) eqn:Hl1. {
  elimtype False; clear - Hl Hl1.
  unfold F.toX in *.
  unfold F.toF in *.
  unfold F.classify in *.
  rewrite FloatAxioms.classify_spec in Hl.
  destruct (FloatOps.Prim2SF l); try destruct s; simpl in *; try discriminate.
}
destruct (F.toX u) eqn:Hu1. {
  elimtype False; clear - Hu Hu1.
  unfold F.toX in *.
  unfold F.toF in *.
  unfold F.classify in *.
  rewrite FloatAxioms.classify_spec in Hu.
  destruct (FloatOps.Prim2SF u); try destruct s; simpl in *; try discriminate.
}
rewrite F.zero_correct.
rewrite F'.real_correct in Hl1, Hu1 by (rewrite F.classify_correct, ?Hl, ?Hu; auto).
inversion Hl1; clear Hl1; subst.
inversion Hu1; clear Hu1; subst.
change Tactic_float.Float.toR with F.toR.
assert (H2l := Rcompare_spec (F.toR l) 0).
assert (H2u := Rcompare_spec (F.toR u) 0).
inversion H2l; clear H2l;
inversion H2u; clear H2u; subst;
simpl; clear H0 H2;
try (rewrite (F.classify_correct (F.neg u)), classify_neg, Hu);
try (rewrite (F.classify_correct (F.neg l)), classify_neg, Hl);
try (rewrite (F.classify_correct l), Hl);
try (rewrite (F.classify_correct u), Hu);
simpl; auto;
rewrite ?toR_neg by (rewrite F.classify_correct, Hu; auto);
rewrite ?toR_neg by (rewrite F.classify_correct, Hl; auto);
try solve [unfold Rabs; destruct (Rcase_abs _); lra].
pose proof (F.max_correct (F.neg l) u).
rewrite classify_neg, Hl,Hu in H0.
rewrite (F'.real_correct (F.neg l)) in H0 by (rewrite F'.real_neg, F.classify_correct, Hl; auto).
rewrite (F'.real_correct u) in H0 by (rewrite F.classify_correct, Hu; auto).
simpl in H0.
rewrite (toX_Xreal_real _ _ H0).
unfold F.toR.
rewrite H0.
simpl.
change Tactic_float.Float.toR with F.toR.
rewrite ?toR_neg by (rewrite F.classify_correct, Hl; auto).
unfold Rabs, Rmax.
destruct (Rcase_abs _), (Rle_dec _ _); try lra.
rewrite H1 in *. rewrite H3 in *.
assert (x=0) by lra.
subst.
rewrite Rabs_R0.
change (F.toR F.zero) with 0.
lra.
Qed.

Lemma b_expr0_correct:
  forall e,
 match fixup_fint (b_expr0 e) with
 | Float.Ibnd lo hi => F.toR lo <= eval e nil <= F.toR hi
 | Float.Inan => True
 end.
Proof.
induction e; simpl; auto.
-
destruct n; simpl; auto.
 + 
  destruct (F.real _) eqn:?H; [ | simpl; auto].
  destruct (F.real (F.fromZ_UP _ _)) eqn:?H; [ | simpl; auto].
  simpl.
  destruct (F.fromZ_DN_correct p52 n) as [_ ?].
  destruct (F.fromZ_UP_correct p52 n) as [_ ?].
  set (lo := F.fromZ_DN p52 n) in *; clearbody lo.
  set (hi := F.fromZ_UP p52 n) in *; clearbody hi.
  pose proof (le_contains _ _ _ H1 H2). clear H1 H2. 
  destruct H3.
  unfold F.toR, proj_val.
  rewrite I.F.real_correct in H,H0.
  change I.F.toX with F.toX in *.
  destruct (F.toX lo); try discriminate.
  destruct (F.toX hi); try discriminate.
  lra.
 +
   destruct r; simpl; auto.
   destruct p; simpl; auto.
   destruct p; simpl; auto.
   pose proof (I.power_int_correct p52 n (fromZ p52 2) (Xreal 2) (fromZ_correct _ 2)).
   simpl in H.
   destruct (I.power_int p52 (fromZ p52 2) n); simpl in *; auto.
   destruct (F.real l) eqn:?H; [ | simpl; auto].
   destruct (F.real u) eqn:?H; [ | simpl; auto].
   simpl.
   rewrite (F'.valid_lb_real _ H0) in H.
   rewrite (F'.valid_ub_real _ H1) in H.
   simpl in H.
   destruct (Xpower_int' 2 n) eqn:?H; try contradiction.
  rewrite I.F.real_correct in H0,H1.
  change I.F.toX with F.toX in *.
  unfold F.toR, proj_val.
  destruct (F.toX l); try discriminate.
  destruct (F.toX u); try discriminate.
  replace (bpow' 2 n) with r; auto.
  clear - H2.
  unfold Xpower_int', bpow' in *.
  destruct n; [ | | rewrite is_zero_false in H2 by lra];
  simpl in H2; injection H2; clear H2; intro H2; subst.
  auto. 
  rewrite Zpower_pos_powerRZ; rewrite pow_powerRZ; f_equal; lia.
  f_equal.
  rewrite Zpower_pos_powerRZ; rewrite pow_powerRZ; f_equal; lia.
-
  destruct u; try solve [simpl; auto].
 + destruct (b_expr0 e); simpl in *; auto.
   rewrite !F'.real_neg.
   change    Tactic_float.Float.real with F.real.
   destruct (F.real u) eqn:?H; [ | simpl; auto].
   destruct (F.real l) eqn:?H; [ | simpl; auto].
   simpl in *.
   pose proof (F'.neg_correct l).
   pose proof (F'.neg_correct u).
   change Tactic_float.Float.toX with F.toX in *.
   change    Tactic_float.Float.neg with F.neg in *.
   unfold F.toR in *. rewrite H1, H2.
  rewrite I.F.real_correct in H,H0.
  change I.F.toX with F.toX in *.
  destruct (F.toX l); try discriminate.
  destruct (F.toX u); try discriminate.
  simpl in *. lra.
 + destruct (b_expr0 e); auto.
   apply fixup_fint_abs_correct; auto.
 + destruct (b_expr0 e); auto.
     set (x := eval e nil) in *. clearbody x; clear e.
     destruct (decent_interval _) eqn:?H; [ | simpl; auto].
     simpl in H. rewrite andb_true_iff in H. destruct H.
     simpl in IHe. rewrite H, H0 in IHe. simpl in IHe.
     rewrite inv_div1 by (simpl; rewrite H, H0; auto).
     pose proof J.div_correct p52 (fromZ p52 1) (Float.Ibnd l u) 1 x.
     match type of H1 with _ -> _ -> ?A => assert A; [apply H1 | ]; clear H1 end.
     apply fromZ_correct.
     hnf; simpl.
     rewrite F'.valid_lb_real by auto.
     rewrite F'.valid_ub_real by auto.
     simpl.
     rewrite F.real_correct in *.
     unfold F.toR in *.
     destruct (F.toX l) eqn:?H; try discriminate.
     destruct (F.toX u) eqn:?H; try discriminate.
     simpl in *. auto.
     change I.div with div in H2.
     set (d := div _ _ _) in *. clearbody d.
     destruct d; simpl in *; auto.
     destruct (F.real l0) eqn:?H; simpl; auto.
     destruct (F.real u0) eqn:?H; simpl; auto.
     rewrite F'.valid_lb_real in H2 by auto.
     rewrite F'.valid_ub_real in H2 by auto. simpl in H2.
     unfold F.toR. rewrite F.real_correct in H1, H3.
     destruct (F.toX l0); try discriminate.
     destruct (F.toX u0); try discriminate.
     unfold Rdiv in H2; rewrite Rmult_1_l in H2.
     simpl; auto.
 + destruct (b_expr0 e); simpl in *; auto.
     destruct (F.real l) eqn:?H; simpl; auto.
     destruct (F.real u) eqn:?H; simpl; auto.
     simpl in IHe.   
     set (x := eval e nil) in *; clearbody x; clear e.
     pose proof (I.power_int_correct p52 n (Float.Ibnd l u) (Xreal x)).
     cbv beta in H1.
     match type of H1 with ?A -> _ => assert A end. {
       red. simpl.
       rewrite F'.valid_lb_real by auto.
       rewrite F'.valid_ub_real by auto.
       simpl.
       unfold F.toR in IHe.
     rewrite F.real_correct in *.
     destruct (F.toX l) eqn:?H; try discriminate.
     destruct (F.toX u) eqn:?H; try discriminate. apply IHe.
    }
    apply H1 in H2; clear H1.
    red in H2. destruct (I.power_int p52 (Float.Ibnd l u) n); simpl in *; auto.
    destruct (F.real l0) eqn:?H; simpl; auto.
    destruct (F.real u0) eqn:?H; simpl; auto.
       rewrite F'.valid_lb_real in H2 by auto.
       rewrite F'.valid_ub_real in H2 by auto.
       simpl in H2.
      destruct (Xpower_int' x n) eqn:?H; try contradiction.
      unfold F.toR.
     rewrite F.real_correct in H1,H3.
     destruct (F.toX l0); try discriminate.
     destruct (F.toX u0); try discriminate.
     simpl.
    destruct n; simpl in *. inversion H4; subst; auto.
    inversion H4; subst; auto.
    destruct (is_zero x); inversion H4; subst; auto.
- destruct b; simpl; auto.
   destruct (b_expr0 e1); try solve [simpl in *; auto].
   simpl in IHe1.
   unfold decent_interval at 1.
   destruct (F.real l) eqn:?H; [ | simpl; auto].
   destruct (F.real u) eqn:?H; [ | simpl; auto].
   destruct (b_expr0 e2); try solve [simpl in *; auto].
   simpl in IHe2.
   unfold decent_interval at 1.
   destruct (F.real l0) eqn:?H; [ | simpl; auto].
   destruct (F.real u0) eqn:?H; [ | simpl; auto].
   pose proof (mul_correct p52 (Float.Ibnd l u) (Float.Ibnd l0 u0) (Xreal (eval e1 nil)) (Xreal (eval e2 nil))).
   simpl in IHe1, IHe2.
   set (x1 := eval e1 nil) in *; clearbody x1.
   set (x2 := eval e2 nil) in *; clearbody x2. clear e1 e2.
   set (m := mul _ _ _) in *. clearbody m.
   simpl.
    unfold F.toR in *.
   match type of H3 with _ -> _ -> ?A => assert A; [apply H3 | clear H3 ] end.
 + (* Mul *)
   hnf; simpl.
       rewrite F'.valid_lb_real by auto.
       rewrite F'.valid_ub_real by auto.
      simpl.
    rewrite F.real_correct in H, H0.
    destruct (F.toX l); try discriminate.
    destruct (F.toX u); try discriminate.
    apply IHe1.
  +
   hnf; simpl.
       rewrite F'.valid_lb_real by auto.
       rewrite F'.valid_ub_real by auto.
      simpl.    
    rewrite F.real_correct in H1, H2.
    destruct (F.toX l0); try discriminate.
    destruct (F.toX u0); try discriminate.
    apply IHe2.
  +
     hnf in H4; simpl in H4.
     destruct m; simpl in *; auto.
     destruct (F.real l1) eqn:?H; [ | simpl; auto].
     destruct (F.real u1) eqn:?H; [ | simpl; auto].
     simpl.
       rewrite F'.valid_lb_real in H4 by auto.
       rewrite F'.valid_ub_real in H4 by auto.
   simpl in H4.
    rewrite F.real_correct in H3, H5.
    destruct (F.toX l1); try discriminate.
    destruct (F.toX u1); try discriminate.
    simpl in *. auto.
Qed.

Definition fint_to_option (x: fint) : option F.type :=
 match x with
 | Float.Ibnd _ hi => Some hi
 | Float.Inan => None
 end.

Definition zero : F.type := F.fromZ_DN p52 0.

Definition hyps_to_interval : list hyp -> Float.f_interval F.type :=
    List.fold_right (fun h x => I.meet (IT2.IH.R.eval_hyp_bnd p52 h) x) Float.Inan.

Lemma hyps_to_interval_correct:
 forall (hs: list hyp) r, 
      Forall (fun h => eval_hyp h r) hs -> 
      contains (convert (hyps_to_interval hs)) (Xreal r).
Proof.
intros.
induction hs; [ apply I | ].
inversion H; clear H; subst.
simpl.
specialize (IHhs H3).
apply I.meet_correct; auto.
clear - H2.
apply (PT2.IH.R.eval_hyp_bnd_correct p52) in H2; auto.
Qed.

Definition b_hyps (h: list hyp) : option F.type :=
   let u := upper (abs (hyps_to_interval h))
   in if F.real u then Some u else None.
  
Lemma b_hyps_correct: forall hs x r,
  b_hyps hs = Some x ->
  Forall (fun h => eval_hyp h r) hs ->
  F.real x = true /\ Rabs r <= F.toR x.
Proof.
intros.
unfold b_hyps in H.
set (u := upper _) in H.
destruct (F.real u) eqn:?H; inversion H; clear H; subst.
split; auto.
apply (hyps_to_interval_correct hs r) in H0.
set (i := hyps_to_interval hs) in *.
clearbody i.
subst u.
destruct i; [ inversion H1 | ].
apply (I2.abs_correct (Float.Ibnd l u) (Xreal r)) in H0.
simpl Xabs in H0.
set (a := abs _) in *; clearbody a.
hnf in H0.
destruct a; try discriminate.
simpl in H1|-*.
simpl in H0.
destruct (F.valid_lb l0) eqn:?H; simpl in H0.
rewrite F'.valid_ub_real in H0 by auto.
destruct H0 as [_ ?].
pose proof (F.real_correct u0). rewrite H1 in H2. 
destruct (F.toX u0) eqn:?H; try discriminate.
rewrite F'.real_correct in H3 by auto.
inversion H3; clear H3; subst.
auto.
lra.
Qed.

Fixpoint fint_eval_expr (e: expr) (env: list fint) : fint :=
match e with
| Evar i => nth i env Float.Inan
| Econst (Int n) => fromZ p52 n
| Econst (Bpow 2 n) => power_int p52 (fromZ p52 2) n
| Eunary op e1 => 
     match fint_eval_expr e1 env with 
     | Float.Inan => Float.Inan
     | b1 => 
          match op with 
          | Inv => inv p52 b1
          | Neg => neg b1
          | Abs => abs b1
          | Sqr => sqr p52 b1
          | _ => Float.Inan
          end
     end
| Ebinary op e1 e2 =>
     match fint_eval_expr e1 env, fint_eval_expr e2 env with
     | Float.Inan, _ => Float.Inan
     | _, Float.Inan => Float.Inan
     | b1, b2 => 
           match op with
           | Mul => mul p52 b1 b2
           | Div => div p52 b1 b2
           | Add  => add p52 b1 b2
           | Sub  => sub p52 b1 b2
           end
     end
| _ => Float.Inan
end.

Definition b_constexpr e := fint_eval_expr e nil.

Lemma fint_eval_expr_correct:
 forall e fenv env, 
     Forall2 (fun i x => contains (convert i) (Xreal x)) fenv env ->
     contains (convert (fint_eval_expr e fenv)) (Xreal (eval e env)).
Proof.
intros.
induction e.
- simpl.
    revert n; induction H; intros; simpl. destruct n; simpl; auto.
    destruct n; simpl; auto.
- simpl; destruct n.
  + apply fromZ_correct.
  + destruct r; auto; try apply I.
      destruct p; auto; try apply I.
      destruct p; auto; try apply I.
      pose proof (power_int_correct p52 n (fromZ p52 2)  (Xreal 2) (fromZ_correct p52 2)).
      cbv beta iota in H.
      unfold nullary_real.
      replace (Xreal (bpow' 2 n)) with (Xpower_int (Xreal 2) n); auto; clear.
      simpl.
      unfold bpow', Xpower_int'.
      destruct n; auto. 
      f_equal. rewrite Zpower_pos_powerRZ.
      rewrite pow_powerRZ. f_equal. lia.
      unfold is_zero.
      rewrite Req_bool_false by lra. f_equal.
      f_equal. rewrite Zpower_pos_powerRZ.
      rewrite pow_powerRZ. f_equal. lia.
  + apply I.
- unfold fint_eval_expr; fold fint_eval_expr.
    destruct (fint_eval_expr e fenv). apply I.
    destruct u; try apply I.
  + (* neg *) 
     simpl eval. set (x := eval e env) in *; clearbody x; clear e env H.
     apply (neg_correct (Float.Ibnd l u0) (Xreal x)); auto.
  + (* abs *) 
     simpl eval. set (x := eval e env) in *; clearbody x; clear e env H.
     apply (abs_correct (Float.Ibnd l u0) (Xreal x)); auto.
  + (* inv *) 
     simpl eval. set (x := eval e env) in *; clearbody x; clear e env H.
     apply (J.inv_correct p52 (Float.Ibnd l u0) x IHe).
  + (* sqr *) 
     simpl eval. set (x := eval e env) in *; clearbody x; clear e env H.
     apply (sqr_correct p52 (Float.Ibnd l u0) (Xreal x)); auto.
-
    unfold fint_eval_expr; fold fint_eval_expr.
    destruct (fint_eval_expr e1 fenv); auto.
    destruct (fint_eval_expr e2 fenv); auto.
    simpl eval.
    set (x1 := eval e1 env) in *; set (x2 := eval e2 env) in *; clearbody x1 x2.
    clear e1 e2 env H.
    unfold binary_real; destruct b.
  + (* add *) 
     apply (add_correct p52 (Float.Ibnd l u) (Float.Ibnd l0 u0) _ _ IHe1 IHe2).
  + (* sub *)
     apply (sub_correct p52 (Float.Ibnd l u) (Float.Ibnd l0 u0) _ _ IHe1 IHe2).
  + (* mul *)
     apply (mul_correct p52 (Float.Ibnd l u) (Float.Ibnd l0 u0) _ _ IHe1 IHe2).
  + (* div *) 
     pose proof (J.div_correct p52 (Float.Ibnd l u) (Float.Ibnd l0 u0) _ _ IHe1 IHe2).
     unfold Xbind2 in H. unfold Xdiv' in H.
     destruct (is_zero x2) eqn:?H; auto.
Qed.

Lemma b_constexpr_correct:
 forall e, contains (convert (b_constexpr e)) (Xreal (eval e nil)).
Proof.
intros.
apply (fint_eval_expr_correct e nil nil).
constructor.
Qed.

Definition check_bound (b: option F.type) (r: R) := 
        match b with
        | Some u => F.real u = true /\ Rabs r <= F.toR u
        | None => True
        end.

Fixpoint b_expr (e: expr) (hyps: list (option F.type)): option F.type :=
match b_constexpr e with
| Float.Ibnd lo hi => if F.real lo && F.real hi then Some (F.max (F.abs lo) (F.abs hi)) else None
| Float.Inan =>
match e with
| Evar i => nth i hyps None
| Eunary Neg e' =>  b_expr e' hyps
| Eunary Abs e' => b_expr e' hyps
| Eunary (PowerInt (Z.pos p)) e' => match b_expr e' hyps with
                             | Some x => let y := I.Fpower_pos_UP p52 x p
                                                  in if F.real y then Some y else None
                             | _ => None
                             end
| Ebinary Mul e1 e2 => match b_expr e1 hyps, b_expr e2 hyps with
                              | Some x1, Some x2 => let y := F.mul_UP p52 x1 x2
                                                        in if F.real y then Some y else None
                              | _, _ => None
                              end
| _ => None
end end.

Lemma Freal_abs: 
  forall x, F.real x = true -> F.real (F.abs x) = true.
Proof.
intros.
pose proof F.abs_correct x.
rewrite F.real_correct in H.
destruct (F.toX x); try discriminate; simpl in *.
destruct H0 as [? _].
rewrite F.real_correct. rewrite H0.
auto.
Qed.

Lemma Fmax_real: forall a b, 
    F.real a = true -> F.real b = true -> F.real (F.max a b) = true.
Proof.
intros.
pose proof F.max_correct a b.
pose proof H; pose proof H0.
rewrite F.classify_correct in H,H0.
destruct (F.classify a); try discriminate.
destruct (F.classify b); try discriminate.
rewrite F.real_correct in *.
destruct (F.toX a); try discriminate.
destruct (F.toX b); try discriminate.
simpl in *.
rewrite H1; auto.
Qed.

Lemma bconstexpr_correct':
  forall e l u x vars, b_constexpr e = Float.Ibnd l u ->
      (if F.real l && F.real u then Some (F.max (F.abs l) (F.abs u)) else None) = Some x ->
      F.real x = true /\ Rabs (eval e vars) <= F.toR x.
Proof.
intros.
destruct (F.real l) eqn:?H; try discriminate.
destruct (F.real u) eqn:?H; try discriminate.
inversion H0; clear H0; subst.
split. apply Fmax_real; apply Freal_abs; auto.
pose proof (b_constexpr_correct e).
replace (eval e vars) with (eval e nil).
2: { clear - H.
      unfold b_constexpr in H.
      revert l u H; induction e; simpl; intros; auto.
      destruct n; discriminate.
      destruct (fint_eval_expr e nil) eqn:?H;try discriminate.
      destruct u; try discriminate;
      rewrite (IHe _ _  (eq_refl _)); auto.
      destruct (fint_eval_expr e1 nil) eqn:?H;try discriminate.
      destruct (fint_eval_expr e2 nil) eqn:?H;try discriminate.
      rewrite (IHe1 _ _ (eq_refl _)); auto.
      rewrite (IHe2 _ _ (eq_refl _)); auto.
}
rewrite H in H0; clear H.
set (r := eval e  nil) in *; clearbody r. clear e.
hnf in H0. simpl in H0.
rewrite F'.valid_lb_real  in H0 by auto.
rewrite F'.valid_ub_real  in H0 by auto.
simpl in H0.
pose proof (Freal_abs _ H1).
pose proof (Freal_abs _ H2).
pose proof (F.max_correct (F.abs l) (F.abs u)).
pose proof H; pose proof H3.
rewrite F.classify_correct in H, H3.
destruct (F.classify _); try discriminate.
destruct (F.classify _); try discriminate.
unfold F.toR.
rewrite H4. clear H4.
destruct H0.
destruct (F.abs_correct l) as [? _].
destruct (F.abs_correct u) as [? _].
rewrite F.real_correct in H1, H2.
destruct (F.toX l) eqn:?H; try discriminate.
destruct (F.toX u) eqn:?H; try discriminate.
rewrite F.real_correct in H5, H6.
destruct (F.toX (F.abs l)) eqn:?H; try discriminate.
destruct (F.toX (F.abs u)) eqn:?H; try discriminate.
simpl.
simpl in H7,H8.
inversion H7. inversion H8. subst.
clear - H0 H4.
unfold Rabs, Rmax.
repeat destruct (Rcase_abs _); destruct (Rle_dec _ _); lra.
Qed.

Lemma b_expr_correct:
  forall hyps vars e x,
    Forall2 check_bound hyps vars ->
    b_expr e hyps = Some x -> 
    F.real x = true /\ Rabs (eval e vars) <= F.toR x.
Proof.
intros.
revert x H0; induction e; unfold b_expr; fold b_expr; intros.
- (* var case *)
unfold b_constexpr in H0.
simpl in H0.
assert (nth n hyps None = Some x) by (destruct n; auto); clear H0.
revert n H1; induction H; intros.
destruct n; inversion H1.
destruct n.
simpl in H1. subst x0.
auto.
simpl.
apply IHForall2. auto.
- (* const case *)
pose proof (b_constexpr_correct (Econst n)).
simpl.
simpl eval in H1.
destruct (b_constexpr (Econst n)) eqn:?. discriminate.
apply (bconstexpr_correct' _ _ _ x vars Heqf H0).
- (* unary case *)
  destruct (b_constexpr (Eunary u e)) eqn:?H. 
  + destruct u; try discriminate.
    * apply IHe in H0. clear - H0.  simpl. rewrite Rabs_Ropp; auto. 
    * apply IHe in H0. clear - H0.  simpl.  rewrite Rabs_Rabsolu; auto.
    * destruct n; try discriminate.
       destruct (b_expr e hyps) eqn:?H; try discriminate.
       destruct (F.real (I.Fpower_pos_UP p52 t p)) eqn:?H; inversion H0; clear H0; subst.
       specialize (IHe _ (eq_refl _)). destruct IHe as [Ht IHe].
       split; auto.
       clear - H3 Ht IHe. simpl. set (i := eval e vars) in *; clearbody i.
       rewrite <- RPow_abs.
       pose proof Ht.
       rewrite F.real_correct in H. unfold F.toR in IHe.
       destruct (F.toX t) eqn:?H; inversion H; clear H; subst.
       simpl in IHe.
       pose proof (I.Fpower_pos_up_correct p52 t p).
       rewrite H0 in H.
       destruct H. apply F'.valid_ub_real; auto.
       simpl. clear - IHe. unfold Rabs in IHe. destruct (Rcase_abs _) in IHe;  lra.
       set (y := I.Fpower_pos_UP _ _ _) in *; clearbody y.
       red in H1.
       rewrite F.real_correct in H3.
       unfold F.toR.
       destruct (F.toX y); try discriminate.
       simpl in H1. simpl.
       eapply Rle_trans; try apply H1.
       apply pow_maj_Rabs. rewrite Rabs_Rabsolu. auto.
   + 
      apply (bconstexpr_correct' _ _ _ x vars H1 H0).
- (* binary case *)
  destruct (b_constexpr (Ebinary b e1 e2)) eqn:?H.
  + destruct b; try discriminate.
     destruct (b_expr e1 hyps) eqn:?H; try discriminate.
     destruct (b_expr e2 hyps) eqn:?H; try discriminate.
     specialize (IHe1 _ (eq_refl _)); destruct IHe1.
     specialize (IHe2 _ (eq_refl _)); destruct IHe2.
     simpl.
     destruct (F.real (F.mul_UP p52 t t0)) eqn:?H; inversion H0; clear H0; subst.
     clear H1. split; auto.
     rewrite Rabs_mult.
     eapply Rle_trans.
     apply Rmult_le_compat.
     apply Rabs_pos.
     apply Rabs_pos. eassumption. eassumption.
     destruct (F.mul_UP_correct p52 t t0).
     left. split.
     split. apply F'.valid_ub_real; auto.
     unfold F.toR in H5. rewrite F.real_correct in H4. destruct (F.toX t); try discriminate.
     simpl in H5. pose proof (Rabs_pos (eval e1 vars)); lra.
     split. apply F'.valid_ub_real; auto.
     unfold F.toR in H7. rewrite F.real_correct in H6. destruct (F.toX t0); try discriminate.
     simpl in H7. pose proof (Rabs_pos (eval e2 vars)); lra.
     unfold Xbind2 in H1.
     red in H1. unfold F.toR. rewrite F.real_correct in H8.
     destruct (F.toX (F.mul_UP p52 t t0)); try discriminate.
     rewrite F.real_correct in H4. destruct (F.toX t); try discriminate.
     rewrite F.real_correct in H6. destruct (F.toX t0); try discriminate. simpl. auto.
  +
      apply (bconstexpr_correct' _ _ _ x vars H1 H0).
Qed.

Definition eval_hyps1 (hyps: list hyp) (r: R) :=
   Forall (fun h => eval_hyp h r) hyps.

Lemma eval_hyps_correct:
  forall hyps vars P, 
    length hyps = length vars ->
     (eval_hyps hyps vars P <->
       (Forall2 eval_hyps1 hyps vars -> P)).
Proof.
induction hyps; destruct vars; simpl; intros; try discriminate.
split; intros; auto.
injection H; clear H; intro.
specialize (IHhyps _ P  H).
split; intros; auto.
inversion H1; clear H1; subst.
apply IHhyps; auto.
set (Q := eval_hyps _ _ P) in *.
clearbody Q.
clear - H0 H5.
induction a; auto.
unfold eval_hyps1 in H5.
inversion H5; clear H5; subst.
eauto.
assert (eval_hyps1 a r -> Forall2 eval_hyps1 hyps vars -> P).
intros.
apply H0.
constructor; auto.
clear H0.
rewrite <- IHhyps in H1; clear IHhyps.
set (Q := eval_hyps _ _ P) in *.
clearbody Q.
clear - H H1.
induction a; auto.
apply H1.
constructor.
intro.
apply IHa.
intro.
apply H1.
constructor; auto.
Qed.

Fixpoint prune (hyps: list (option F.type)) (e: expr) (cutoff: F.type) :
           expr * F.type :=
 match b_expr e hyps with 
 | Some b => if F'.le b cutoff then (zeroexpr, b) else (e,zero)
 | None =>
 match e with
 | Ebinary Add e1 e2 =>
  let (e1',b1) := prune hyps e1 cutoff in 
  let (e2',b2) := prune hyps e2 cutoff in 
  (match e1', e2'  with
   | Econst (Int 0), _ => e2'
   | _, Econst (Int 0) => e1'
   | _, _ => Ebinary Add e1' e2'
   end, if F.real b1 && F.real b2 then F.add_UP p52 b1 b2 else infinity)
 | Ebinary Sub e1 e2 =>
  let (e1',b1) := prune hyps e1 cutoff in 
  let (e2',b2) := prune hyps e2 cutoff in 
  (match e1', e2' with
   | Econst (Int 0), _ => Eunary Neg e2'
   | _, Econst (Int 0) => e1'
   | _, _ => Ebinary Sub e1' e2'
   end, if F.real b1 && F.real b2 then F.add_UP p52 b1 b2 else infinity)
 | _ => (e, zero)
 end
end.

Lemma FtoR_zero: F.toR zero = 0.
Proof.
unfold F.toR. change zero with F.zero. rewrite F.zero_correct. reflexivity.
Qed.

Lemma prune_correct:
  forall env e cutoff e1 slop,
  prune env e cutoff = (e1,slop) ->
  F.real slop = true ->
  forall (vars: list R),
   Forall2 check_bound env vars ->
   Rabs (eval e vars - eval e1 vars) <= F.toR slop.
Proof.
intros until 1.
intro Hslop.
revert e1 slop H Hslop.
 induction e; intros; unfold prune in H; fold prune in H;
 try solve [
  match type of H with context [b_expr ?e ?env] => destruct (b_expr e env) eqn:?H end;
    [destruct (F'.le t cutoff) eqn:?H; inversion H; clear H; subst;
     apply (b_expr_correct _ vars _ _ H0) in H1;
     [destruct H1; simpl in H1|-*; rewrite Rminus_0_r; auto
     | rewrite Rminus_eq_0, Rabs_R0, FtoR_zero; lra
     ]
    | inversion H; clear H; subst; rewrite Rminus_eq_0, Rabs_R0, FtoR_zero; lra
    ]].
(* binary case *)
 destruct (b_expr (Ebinary b e1 e2) env) eqn:?H.
-
 destruct (b_expr_correct env vars (Ebinary b e1 e2) _ H0 H1); clear H1.
 destruct (F'.le t cutoff) eqn:?H.
    inversion H; clear H; subst.
    simpl eval in *. rewrite Rminus_0_r. auto.
    inversion H; clear H; subst. rewrite Rminus_eq_0, FtoR_zero, Rabs_R0; lra.
-
     destruct (prune env e1 cutoff) as [e1' b1].
     destruct (prune env e2 cutoff) as [e2' b2].
     specialize (IHe1 _ _ (eq_refl _)).
     specialize (IHe2 _ _ (eq_refl _)).
   clear H1.
 destruct b.
 + (* Add *)
     injection H; clear H; intros H H'.
     subst slop.
     destruct (F.real b1) eqn:R1; try discriminate.
     destruct (F.real b2) eqn:R2; try discriminate. simpl in Hslop.
     specialize (IHe1 (eq_refl _) _ H0).
     specialize (IHe2 (eq_refl _) _ H0).
     simpl in *.
     destruct (F.add_UP_correct p52 b1 b2); auto.
         apply F'.valid_ub_real; auto.
         apply F'.valid_ub_real; auto.
     red in H1.
     unfold F.toR  in *.
     rewrite F.real_correct in R1,R2.
     destruct (F.toX b1); try discriminate.
     destruct (F.toX b2); try discriminate.
     rewrite F.real_correct in Hslop. destruct ( F.toX (F.add_UP p52 b1 b2)); try discriminate.
     simpl in *.
     subst e0; revert IHe1 IHe2.
     destruct e1' as [ | [ [ | | ] | | ] | | ] ;
     destruct e2' as [ | [ [ | | ] | | ] | | ] ;
     simpl;
     unfold Rabs; repeat destruct (Rcase_abs _); lra.
 + (* Sub *)
     injection H; clear H; intros H H'.
     subst slop.
     destruct (F.real b1) eqn:R1; try discriminate.
     destruct (F.real b2) eqn:R2; try discriminate. simpl in Hslop.
     specialize (IHe1 (eq_refl _) _ H0).
     specialize (IHe2 (eq_refl _) _ H0).
     simpl in *.
     destruct (F.add_UP_correct p52 b1 b2); auto.
         apply F'.valid_ub_real; auto.
         apply F'.valid_ub_real; auto.
     red in H1.
     unfold F.toR  in *.
     rewrite F.real_correct in R1,R2.
     destruct (F.toX b1); try discriminate.
     destruct (F.toX b2); try discriminate.
     rewrite F.real_correct in Hslop. destruct ( F.toX (F.add_UP p52 b1 b2)); try discriminate.
     simpl in *.
     subst e0; revert IHe1 IHe2.
     destruct e1' as [ | [ [ | | ] | | ] | | ] ;
     destruct e2' as [ | [ [ | | ] | | ] | | ] ;
     simpl;
     unfold Rabs; repeat destruct (Rcase_abs _); lra.
 + inversion H; clear H; subst. rewrite Rminus_eq_0, FtoR_zero, Rabs_R0; lra.
 + inversion H; clear H; subst. rewrite Rminus_eq_0, FtoR_zero, Rabs_R0; lra.
Qed.

Lemma prune_terms_correct:
 forall hyps e cutoff e1 slop, 
   prune (map b_hyps hyps) e cutoff = (e1,slop) ->
  F.real slop = true ->
   forall vars r, 
     length hyps = length vars ->
     eval_hyps hyps vars (Rabs (eval e1 vars) <= r - F.toR slop) ->
      eval_hyps hyps vars (Rabs (eval e vars) <= r).
Proof.
intros.
apply eval_hyps_correct ; auto.
intros.
apply eval_hyps_correct in H2; auto.
clear H1.
assert (Forall2 check_bound (map b_hyps hyps) vars). {
clear - H3.
induction H3.
constructor.
constructor; auto.
clear - H.
destruct (b_hyps x) eqn:?H; auto.
2: simpl; auto.
simpl.
eapply b_hyps_correct in H0.
apply H0.
clear - H.
induction x.
constructor.
unfold eval_hyps1 in H.
inversion H; clear H; subst.
constructor; auto.
} clear H3.
pose proof (prune_correct _ _ _ _ _ H H0 vars H1).
clear - H2 H3.
revert H2 H3.
unfold Rabs. repeat destruct (Rcase_abs _); intros; lra.
Qed.

Fixpoint count_nodes (e: expr) : Z :=
 match e with
 | Eunary _ e1 => 1 + count_nodes e1
 | Ebinary _ e1 e2 => 1 + count_nodes e1 + count_nodes e2
 | _ => 1
 end.

Fixpoint count_terms (e: expr) : Z :=
 match e with
 | Ebinary Add e1 e2 => count_terms e1 + count_terms e2
 | Ebinary Sub e1 e2 => count_terms e1 + count_terms e2
 | _ => 1
 end.

Require QArith.

Definition Add0 (e1 e2: expr) :=
 match e1 with
 | Econst (Int 0) => e2
 | _ => match e2 with
            | Econst (Int 0) => e1
            | _ => Ebinary Add e1 e2
            end
  end.

Lemma Add0_correct: forall e1 e2, Add0 e1 e2 == Ebinary Add e1 e2.
Proof.
intros. intro.
destruct e1 as [ | [ [ | | ] | | ] | | ]; simpl; auto;
destruct e2 as [ | [ [ | | ] | | ] | | ]; simpl; auto; 
lra.
Qed.

Add Parametric Morphism : Add0
  with signature expr_equiv ==> expr_equiv ==> expr_equiv
  as Add0_mor.
Proof.
intros. rewrite ?Add0_correct. rewrite H,H0; reflexivity.
Qed.

Definition Sub0 (e1 e2: expr) :=
 match e2 with
 | Econst (Int 0) => e1
 | _ => Ebinary Sub e1 e2
  end.

Lemma Sub0_correct: forall e1 e2, Sub0 e1 e2 == Ebinary Sub e1 e2.
Proof.
intros. intro.
destruct e2 as [ | [ [ | | ] | | ] | | ]; simpl; auto; 
lra.
Qed.

Definition powers := list nat.
Definition coefficient := (QArith_base.Q * Z)%type.
Definition normterm := (powers * coefficient)%type.
  (* Define normterm as a pair rather than a Record because it matches
   the result of FMap.elements *)

Definition nt_coeff (n: normterm) := fst (snd n).
Definition nt_exp (n: normterm) := snd (snd n).
Definition nt_powers (n: normterm) := fst n.

Fixpoint reflect_power k v e :=
 match k with
 | O => e
 | S k' => Ebinary Mul (reflect_power k' v e) v
 end.

Add Parametric Morphism : reflect_power
 with signature eq ==> expr_equiv ==> expr_equiv ==> expr_equiv as 
    reflect_power_mor.
Proof.
induction y; simpl; intros; auto.
apply Ebinary_mor; auto.
Qed.

Fixpoint reflect_powers al n e : expr :=
 match al with
 | nil => e
 | k :: al' => reflect_power k (Evar n) (reflect_powers al' (S n) e)
 end.

Add Parametric Morphism : reflect_powers 
 with signature eq ==> eq ==> expr_equiv ==> expr_equiv as 
    reflect_powers_mor.
Proof.
induction y; simpl; intros; auto.
apply reflect_power_mor; auto.
reflexivity.
Qed.

Definition reflect_coeff (x: coefficient) :=
  let '({|QArith_base.Qnum := n; QArith_base.Qden := d|}, e) := x in
 if Z.eqb n 0 then Econst (Int 0) else
 let en := Econst (Int n) in
 let ed := Eunary Inv (Econst (Int (Zpos d))) in 
 let ee := Econst (Bpow 2 e) in
    match Z.eqb n 1, Pos.eqb d 1, Z.eqb e 0 with
    | true,true,true => oneexpr
    | true,true,false => ee
    | true,false,true => ed
    | true,false,false => Ebinary Mul ed ee
    | false,true,true => en
    | false,true,false => Ebinary Mul en ee
    | false,false,true => Ebinary Mul en ed
    | false,false,false => Ebinary Mul (Ebinary Mul en ed) ee
    end.

Definition reflect_coeff_simple (x: coefficient) :=
  let '({|QArith_base.Qnum := n; QArith_base.Qden := d|}, e) := x in
 let en := Econst (Int n) in
 let ed := Eunary Inv (Econst (Int (Zpos d))) in 
 let ee := Econst (Bpow 2 e) in
 Ebinary Mul (Ebinary Mul en ed) ee.

Lemma reflect_coeff_spec (x: coefficient) : reflect_coeff x == reflect_coeff_simple x.
Proof.
destruct x as [[n d] e].
unfold reflect_coeff, reflect_coeff_simple.
destruct (Z.eqb_spec n 0).
subst; intro; simpl; ring.
destruct (Z.eqb_spec n 1), (Pos.eqb_spec d 1), (Z.eqb_spec e 0);
subst; intro; simpl; rewrite ?Rinv_1; ring.
Qed.

Definition reflect_normterm (x: normterm) : expr :=
  let '(al,ec) := x in 
     reflect_powers al O (reflect_coeff ec).

Definition reflect_normterm_simple (x: normterm) : expr :=
  let '(al,ec) := x in 
  Ebinary Mul (reflect_powers al O oneexpr) (reflect_coeff_simple ec).

Lemma reflect_powers_untangle:
  forall p i e, 
  reflect_powers p i e == Ebinary Mul (reflect_powers p i oneexpr) e.
Proof.
intros. intro.
revert i e; induction p; simpl; intros; auto.
lra.
specialize (IHp (S i) e).
induction a; simpl; auto.
rewrite IHa.
lra.
Qed.

Lemma reflect_normterm_spec (x: normterm) :
  reflect_normterm x == reflect_normterm_simple x.
Proof.
unfold reflect_normterm, reflect_normterm_simple.
destruct x.
rewrite reflect_powers_untangle.
rewrite reflect_coeff_spec.
reflexivity.
Qed.

Lemma reflect_powers_ext:
  forall p i e1 e2, 
    e1 == e2 ->
   reflect_powers p i e1 == reflect_powers p i e2.
Proof.
intros.
revert i e1 e2 H; induction p; simpl; intros; auto.
induction a; simpl; auto.
intro; simpl; f_equal. auto.
Qed.


Fixpoint merge_powers (al bl: powers) :=
 match al, bl with
 | nil, _ => bl
 | _, nil => al 
 | a::al', b::bl' => (a+b)%nat :: merge_powers al' bl'
 end.

Definition mult_normterm (x y : normterm) : normterm :=
 let '(xp,(xc,xe)) := x in
 let '(yp,(yc,ye)) := y in 
   (merge_powers xp yp, (Qreduction.Qmult' xc yc, Z.add xe ye)).

Definition negate_normterm (x: normterm) :=
 let '(xp,(xc,xe)) := x in (xp, (QArith_base.Qopp xc, xe)).

Fixpoint factor_powers_pos (p: positive) : positive * Z :=
 match p with
 | xO p' => let '(r,i) := factor_powers_pos p' in (r, Z.succ i)
 | _ => (p,0%Z)
 end.

Definition factor_powers (i: Z) : Z * Z :=
 match i with
 | Z0 => (Z0,Z0)
 | Zpos p => let '(p,k) := factor_powers_pos p in (Zpos p, k)
 | Zneg p => let '(p,k) := factor_powers_pos p in (Zneg p, k)
 end.

Lemma factor_powers_pos_nonneg:
  forall p, Z.le 0 (snd (factor_powers_pos p)).
Proof.
induction p; simpl; try lia.
destruct (factor_powers_pos p).
simpl in *. lia.
Qed.

Lemma factor_powers_nonneg:
  forall z, Z.le 0 (snd (factor_powers z)).
Proof.
destruct z; simpl; try lia.
pose proof (factor_powers_pos_nonneg p).
destruct (factor_powers_pos p); simpl in *; lia.
pose proof (factor_powers_pos_nonneg p).
destruct (factor_powers_pos p); simpl in *; lia.
Qed.

Lemma factor_powers_correct: forall i,
  let '(z,k) := factor_powers i in
  i = (z * Z.pow 2 k)%Z.
Proof.
intros.
destruct i; simpl; auto;
destruct (factor_powers_pos p) as [q k] eqn:H.
-
revert q k H; induction p; simpl; intros.
inversion H; clear H; subst; simpl. lia.
pose proof (factor_powers_pos_nonneg p).
destruct (factor_powers_pos p).
inversion H; clear H; subst.
specialize (IHp _ _ (eq_refl _)).
simpl in IHp.
rewrite Z.pow_succ_r; auto.
destruct (2^z)%Z; try discriminate.
inversion IHp; clear IHp; subst.
simpl. lia.
inversion H; clear H; subst.
simpl. auto.
-
revert q k H; induction p; simpl; intros.
inversion H; clear H; subst; simpl. lia.
pose proof (factor_powers_pos_nonneg p).
destruct (factor_powers_pos p).
inversion H; clear H; subst.
specialize (IHp _ _ (eq_refl _)).
simpl in IHp.
rewrite Z.pow_succ_r; auto.
destruct (2^z)%Z; try discriminate.
inversion IHp; clear IHp; subst.
simpl. lia.
inversion H; clear H; subst.
simpl. auto.
Qed.

Definition Qone := {|QArith_base.Qnum:=1%Z; QArith_base.Qden := 1%positive|}.
Definition Qmone := {|QArith_base.Qnum:=-1%Z; QArith_base.Qden := 1%positive|}.

Fixpoint normalizable (e: expr) : bool :=
match e with
| Ebinary Mul e1 e2 => if normalizable e1 then normalizable e2 else false
| Econst (Int i) => true
| Eunary Inv (Econst (Int i)) => true
 | Econst (Bpow 2 k) => true
 | Eunary Inv (Econst (Bpow 2 k)) => true
| Evar i => true
| _ => false
end.

Definition inverse_term (i: Z): option normterm :=
   match factor_powers i with
       | (Z0,_) => None
       | (Zpos p, k) => 
           Some (nil, ({|QArith_base.Qnum:=1%Z; QArith_base.Qden:=p|}, Z.opp k))
       | (Zneg p, k) => 
           Some (nil, ({|QArith_base.Qnum:=(-1)%Z; QArith_base.Qden:=p|}, Z.opp k))
       end.

Fixpoint normalize_term (e: expr) : option normterm :=
match e with
| Ebinary Mul e1 e2 =>
      match normalize_term e1, normalize_term e2 with
      | Some e1', Some e2' => Some (mult_normterm e1' e2')
      | _, _ => None
      end
| Econst (Int i) => let '(z,k) := factor_powers i in 
                Some (nil, (QArith_base.inject_Z z, k))
| Eunary Inv (Econst (Int i)) => inverse_term i
 | Econst (Bpow 2 k) => 
            Some (nil, (Qone, k))
 | Eunary Inv (Econst (Bpow 2 k)) => 
            Some (nil, (Qone, Z.opp k))
 | Ebinary Div (Econst (Int 1)) (Econst (Int i)) => inverse_term i
 | Ebinary Div (Econst (Int (-1))) (Econst (Int i)) => inverse_term (-i)
| Evar i => Some (repeat O i ++ 1%nat::nil, (Qone, Z0))
| _ => None
end.

Lemma reflect_power_untangle:
  forall i e1 e2, 
   reflect_power i e1 e2 ==
   Ebinary Mul (reflect_power i e1 oneexpr) e2.
Proof.
intros. intro.
induction i; simpl; intros.
lra.
rewrite IHi. simpl; lra.
Qed.

Lemma merge_powers_correct:
  forall va vb i,
   reflect_powers (merge_powers va vb) i oneexpr ==
   Ebinary Mul  (reflect_powers va i oneexpr) (reflect_powers vb i oneexpr).
Proof.
 induction va; destruct vb; intros; intro; simpl in *; try lra.
specialize (IHva vb (S i) env).
rewrite !(reflect_power_untangle _ _ (reflect_powers _ _ _)).
simpl.
rewrite IHva; clear IHva.
simpl.
set (u := eval (reflect_powers _ _ _) _); clearbody u.
set (u0 := eval (reflect_powers _ _ _) _); clearbody u0.
transitivity (eval (reflect_power a (Evar i) oneexpr) env *
 eval (reflect_power n (Evar i) oneexpr) env * (u * u0)).
2: lra.
f_equal.
induction a; simpl.
lra.
rewrite IHa.
lra.
Qed.

Lemma inverse_term_correct: forall i nt,
 inverse_term i = Some nt ->
   reflect_normterm nt == Eunary Inv (Econst (Int i)).
Proof.
intros.
rewrite reflect_normterm_spec.
unfold reflect_normterm_simple.
destruct nt.
unfold inverse_term in H.
pose proof (factor_powers_nonneg i).
pose proof (factor_powers_correct i).
destruct (factor_powers i); simpl in *; subst.
unfold reflect_coeff_simple.
destruct z; simpl in *.
-
discriminate.
-
inversion H; clear H; subst.
unfold reflect_powers.
intro; simpl. ring_simplify.
destruct z0; try lia.
simpl. rewrite Rmult_1_r, Pos.mul_1_r. auto.
clear H0.
unfold bpow'.
simpl.
pose proof (Zpower_pos_gt_0 2 p ltac:(lia)).
destruct (Z.pow_pos 2 p); try lia.
rewrite <- Rinv_mult_distr by (apply not_0_IZR; lia). 
rewrite <- mult_IZR, <- Pos2Z.inj_mul. auto.
-
inversion H; clear H; subst.
intro; simpl. ring_simplify.
rewrite Ropp_inv_permute by (apply not_0_IZR; lia).
destruct z0; try lia.
simpl. rewrite Rmult_1_r, Pos.mul_1_r.
reflexivity.
unfold bpow'.
simpl.
pose proof (Zpower_pos_gt_0 2 p ltac:(lia)).
destruct (Z.pow_pos 2 p); try lia.
rewrite <- opp_IZR.
rewrite <- Rinv_mult_distr by (apply not_0_IZR; lia). 
f_equal.
rewrite <- mult_IZR.
reflexivity.
Qed.

Lemma bpow'_add: forall a b, bpow' 2 (a+b) = bpow' 2 a * bpow' 2 b.
Proof.
unfold bpow';
intros.
destruct a, b; simpl; rewrite ?Zpower_pos_is_exp, ?mult_IZR,
   ?Rinv_mult_distr by (apply not_0_IZR; lia); try lra.
-
rewrite (Z.pos_sub_spec p p0).
destruct (Pos.compare_spec p p0).
subst. symmetry. apply Rinv_r. apply not_0_IZR; lia.
assert (p0 = p + (p0 - p))%positive by lia.
rewrite H0 at 2.
rewrite ?Zpower_pos_is_exp, ?mult_IZR.
rewrite Rinv_mult_distr by (apply not_0_IZR; lia).
rewrite <- Rmult_assoc.
rewrite Rinv_r by (apply not_0_IZR; lia).
lra.
assert (p = (p-p0)+p0)%positive by lia.
rewrite H0 at 2.
rewrite ?Zpower_pos_is_exp, ?mult_IZR.
rewrite Rmult_assoc.
rewrite Rinv_r by (apply not_0_IZR; lia).
lra.
-
rewrite (Z.pos_sub_spec p0 p).
destruct (Pos.compare_spec p0 p).
subst. symmetry. rewrite Rmult_comm. apply Rinv_r. apply not_0_IZR; lia.
assert (p = (p-p0)+p0)%positive by lia.
rewrite H0 at 2.
rewrite ?Zpower_pos_is_exp, ?mult_IZR.
rewrite Rinv_mult_distr by (apply not_0_IZR; lia).
rewrite Rmult_assoc.
rewrite (Rmult_comm _ (IZR _)).
rewrite Rinv_r by (apply not_0_IZR; lia).
lra.
assert (p0 = p + (p0 - p))%positive by lia.
rewrite H0 at 2.
rewrite ?Zpower_pos_is_exp, ?mult_IZR.
rewrite <- Rmult_assoc.
rewrite (Rmult_comm (/ _)).
rewrite Rinv_r by (apply not_0_IZR; lia).
lra.
Qed.

Lemma mult_normterm_correct:
  forall a b, 
  reflect_normterm (mult_normterm a b) ==
  Ebinary Mul (reflect_normterm a) (reflect_normterm b).
Proof.
intros.
simpl.
rewrite ?reflect_normterm_spec.
destruct a as [va [[na da] ea]], b as [vb [[nb db] eb]].
unfold mult_normterm.
pose proof (Qreduction.Qmult'_correct 
           {| QArith_base.Qnum := na; QArith_base.Qden := da |}
           {| QArith_base.Qnum := nb; QArith_base.Qden := db |}).
set (j := Qreduction.Qmult' _ _). fold j in H. clearbody j.
unfold reflect_normterm_simple.
rewrite merge_powers_correct.
transitivity (Ebinary Mul (Ebinary Mul (reflect_powers va 0 oneexpr)
                          (reflect_powers vb 0 oneexpr))
                  (Ebinary Mul
                    (reflect_coeff_simple ({| QArith_base.Qnum := na; QArith_base.Qden := da |}, ea))
                    (reflect_coeff_simple ({| QArith_base.Qnum := nb; QArith_base.Qden := db |}, eb))));
  [ | intro; simpl; ring].
apply Ebinary_mor; auto. reflexivity.
unfold reflect_coeff_simple.
destruct j.
red in H. simpl in H.
intro; simpl.
rewrite bpow'_add.
field_simplify.
2: split; apply not_0_IZR; lia.
2: apply not_0_IZR; lia.
rewrite <- mult_IZR.
rewrite <- Pos2Z.inj_mul.
apply Stdlib.Rdiv_eq_reg; [ | apply not_0_IZR; lia .. ].
transitivity (IZR (na * nb * Z.pos Qden) * (bpow' 2 ea * bpow' 2 eb)).
rewrite <- H; clear H.
rewrite mult_IZR.
field.
rewrite !mult_IZR.
 field.
Qed.

Lemma normalize_term_correct: 
  forall e nt, normalize_term e = Some nt ->
            reflect_normterm nt == e.
Proof.
intros. intro.
rewrite reflect_normterm_spec.
revert nt H.
induction e; simpl; intros.
-
inversion H; clear H; subst.
unfold reflect_normterm_simple.
simpl.
rewrite Rinv_1.
rewrite !Rmult_1_r.
set (i := 0%nat) at 3.
replace n with (n+i)%nat at 2 by lia.
clearbody i.
revert i env; induction n; simpl; intros.
lra.
replace (S (n+i))%nat with (n + S i)%nat by lia.
apply IHn.
-
destruct n; try discriminate.
+
 simpl.
 pose proof (factor_powers_nonneg n).
 pose proof (factor_powers_correct n).
 destruct (factor_powers n). subst. 
 inversion H; clear H; subst nt. simpl in H0. 
 simpl.
 pose proof (Z.eqb_spec z 0). destruct H; subst.
 simpl. ring. ring_simplify.
 rewrite Rinv_1, !Rmult_1_r.
 rewrite mult_IZR. f_equal.
 unfold bpow'.
 destruct z0; simpl; auto; try lia.
+ destruct r; try discriminate. destruct p; try discriminate.
   destruct p; try discriminate. inversion H; clear H; subst.
 simpl. lra.
-
 destruct u; try discriminate.
 destruct e; try discriminate.
 destruct n; try discriminate.
 simpl in IHe.
 pose proof (factor_powers_nonneg n).
 pose proof (factor_powers_correct n).
 destruct (factor_powers n).
 specialize (IHe _ (eq_refl _)).
 pose proof (inverse_term_correct _ _ H env).
  rewrite reflect_normterm_spec in H2.
  auto.
 destruct r; try discriminate.
 destruct p; try discriminate.
 destruct p; try discriminate.
 inversion H; clear H; subst.
 specialize (IHe _ (eq_refl _)).
 simpl in IHe. simpl.
 unfold bpow'.
 destruct n; simpl; auto. lra. lra.
 rewrite Rinv_involutive.
 2: apply not_0_IZR; lia. lra.
-
 destruct b; try discriminate.
 +
 destruct (normalize_term e1) eqn:?H; try discriminate.
 destruct (normalize_term e2) eqn:?H; try discriminate.
 specialize (IHe1 _ (eq_refl _)).
 specialize (IHe2 _ (eq_refl _)).
 inversion H; clear H; subst.
 simpl binary_real.
 rewrite <- IHe1, <- IHe2.
 rewrite <- !reflect_normterm_spec.
 apply mult_normterm_correct.
 +
  destruct e1; try discriminate.
  destruct n; try discriminate;
  destruct n; try discriminate;
  destruct p; try discriminate;
  destruct e2; try discriminate;
  destruct n; try discriminate;
  assert (Hn: n<>0%Z) by (intro; subst n; inversion H).
 simpl.
 pose proof (inverse_term_correct _ _ H env).
  rewrite reflect_normterm_spec in H0.
 rewrite H0; simpl. lra.
 pose proof (inverse_term_correct _ _ H env).
  rewrite reflect_normterm_spec in H0.
 rewrite H0; simpl.
 rewrite opp_IZR.
 rewrite <- Ropp_inv_permute by (apply not_0_IZR; auto).
  lra.
Qed.

Fixpoint normalize_terms (negate: bool) (e: expr) (nl: list normterm) : expr * list normterm :=
 match e with
 | Ebinary Add e1 e2 => 
      let '(e2',nl') := normalize_terms negate e2 nl in
      let '(e1',nl'') := normalize_terms negate e1 nl' in
       (Add0 e1' e2', nl'')
 | Ebinary Sub e1 e2 => 
      let '(e2',nl') := normalize_terms (negb negate) e2 nl in
      let '(e1',nl'') := normalize_terms negate e1 nl' in
       (Add0 e1' e2', nl'')
 | Eunary Neg e1 => normalize_terms (negb negate) e1 nl
 | _ => match normalize_term e with 
            | Some nt => (zeroexpr, 
                                   (if negate then negate_normterm nt else nt) :: nl)
            | None => (if negate then Eunary Neg e else e, nl)
            end
  end.

Definition reflect_normterms (nts: list normterm) (e: expr) :=
   fold_right (fun nt e1 => Ebinary Add (reflect_normterm nt) e1) e nts.

Lemma negate_normterm_correct:
  forall nt, 
   reflect_normterm (negate_normterm nt) == Eunary Neg  (reflect_normterm nt).
Proof.
intros. intro; simpl.
rewrite !reflect_normterm_spec.
destruct nt as [p [[n d] e]].
simpl.
rewrite opp_IZR.
ring.
Qed.

Lemma reflect_normterms_untangle:
  forall nl e, 
  reflect_normterms nl e ==  Ebinary Add (reflect_normterms nl zeroexpr) e.
Proof.
intros. intro. simpl.
revert e; induction nl; simpl; intros.
lra.
rewrite IHnl. lra.
Qed.

Lemma normalize_terms_correct:
  forall sign e nl,
  let '(e1, nts) := normalize_terms sign e nl in
  reflect_normterms nts e1 == 
    Ebinary Add (Ebinary Mul (if sign then moneexpr else oneexpr) e) (reflect_normterms nl zeroexpr).
Proof.
intros.
destruct (normalize_terms sign _ nl) eqn:?H.
intro. simpl.
revert sign nl e0 l H; induction e; intros.
-
unfold normalize_terms in H.
destruct (normalize_term (Evar n)) eqn:?H.
 + inversion H; clear H; subst. 
  pose proof (normalize_term_correct _ _ H0 env).
  unfold reflect_normterms.
  rewrite <- H.
 simpl.
 set (u := eval (fold_right _ _ _) _ ); clearbody u.
 destruct sign.
 rewrite negate_normterm_correct. simpl; lra.
 simpl; lra.
 + inversion H; clear H; subst.
   destruct sign.
 rewrite (reflect_normterms_untangle _ (Eunary _ _)).
  simpl; lra.
 rewrite (reflect_normterms_untangle _ (Evar _)).
  simpl; lra.
- unfold normalize_terms in H.
  destruct (normalize_term (Econst n)) eqn:?H.
 +
     pose proof (normalize_term_correct _ _ H0 env).
  inversion H; clear H; subst.
  destruct sign.
  rewrite <- H1; clear H1.
  unfold reflect_normterms. simpl.
 rewrite negate_normterm_correct. simpl; lra.
 rewrite <- H1.
  unfold reflect_normterms; simpl; lra.
 + inversion H; clear H; subst.
   destruct sign.
  rewrite reflect_normterms_untangle.
 simpl. lra.
  rewrite reflect_normterms_untangle.
 simpl. lra.
-
 destruct u;
  try solve [
 simpl in H; inversion H; clear H; subst;
 destruct sign; simpl;
 rewrite reflect_normterms_untangle; simpl; lra].
 + (* Neg *)
 simpl. 
 simpl in H. apply IHe in H. rewrite H.
 destruct sign; simpl; lra.
 + (* Inv *)
  simpl in H.
  destruct e; 
  try solve [
 simpl in H; inversion H; clear H; subst;
 destruct sign; simpl;
 rewrite reflect_normterms_untangle; simpl; lra].
 destruct n;
  try solve [
 simpl in H; inversion H; clear H; subst;
 destruct sign; simpl;
 rewrite reflect_normterms_untangle; simpl; lra].
 destruct (inverse_term n) eqn:?H; 
  try solve [
 simpl in H; inversion H; clear H; subst;
 destruct sign; simpl;
 rewrite reflect_normterms_untangle; simpl; lra].
 inversion H; clear H; subst.
 pose proof (inverse_term_correct _ _ H0 env).
  simpl. clear IHe H0. simpl in H. rewrite <- H.
 destruct sign; simpl.
 rewrite negate_normterm_correct. simpl; lra.
  lra.
 destruct r;
  try solve [
 simpl in H; inversion H; clear H; subst;
 destruct sign; simpl;
 rewrite reflect_normterms_untangle; simpl; lra].
 destruct p;
  try solve [
 simpl in H; inversion H; clear H; subst;
 destruct sign; simpl;
 rewrite reflect_normterms_untangle; simpl; lra].
 destruct p;
  try solve [
 simpl in H; inversion H; clear H; subst;
 destruct sign; simpl;
 rewrite reflect_normterms_untangle; simpl; lra].
 clear IHe.
 inversion H; clear H; subst.
 destruct sign; simpl.
 destruct (Z.eqb_spec n 0). subst. simpl. lra.
 destruct (Z.eqb_spec (-n) 0). lia.
 simpl. f_equal. f_equal.
 unfold bpow'. destruct n; simpl; auto; try lra.
 rewrite Rinv_involutive.
 2: apply not_0_IZR; lia. lra.
 destruct (Z.eqb_spec n 0). subst. simpl. lra.
 destruct (Z.eqb_spec (-n) 0). lia.
 simpl. f_equal. f_equal.
 unfold bpow'. destruct n; simpl; auto; try lra.
 rewrite Rinv_involutive.
 2: apply not_0_IZR; lia. lra.
-
destruct b;
try solve [
  clear IHe1 IHe2; unfold normalize_terms in H;
  match goal with |- context [Ebinary ?op] => set (e := Ebinary op e1 e2) in *; clearbody e end;
  rewrite reflect_normterms_untangle; simpl;
  destruct (normalize_term e) eqn:H0; inversion H; clear H; subst;
  destruct sign; simpl;
  rewrite ?negate_normterm_correct; simpl;
  rewrite ?(normalize_term_correct _ _ H0); simpl;
  lra].
+ (* Add *)
   simpl in *.
   destruct (normalize_terms sign e2 nl) as [e2' nl'] eqn:H2.
   destruct (normalize_terms sign e1 nl') as [e1' nl''] eqn:H1.
   apply IHe1 in H1. apply IHe2 in H2. clear IHe1 IHe2.
   inversion H; clear H; subst.
   rewrite reflect_normterms_untangle. simpl.
  rewrite Add0_correct. simpl.
  rewrite reflect_normterms_untangle in H1,H2. simpl in H1,H2. lra.
+ (* Sub *)
   simpl in *.
   destruct (normalize_terms (negb sign) e2 nl) as [e2' nl'] eqn:H2.
   destruct (normalize_terms sign e1 nl') as [e1' nl''] eqn:H1.
   apply IHe1 in H1. apply IHe2 in H2. clear IHe1 IHe2.
   inversion H; clear H; subst.
   rewrite reflect_normterms_untangle. simpl.
  rewrite reflect_normterms_untangle in H1,H2. simpl in H1,H2.
  rewrite Add0_correct. simpl.
  destruct sign; unfold negb in H2;
  change (eval moneexpr env) with (-1) in *; change (eval oneexpr env) with 1 in *;
  lra.
Qed.

Require FMapInterface.

Module Keys <: OrderedType.OrderedType.
  Definition t := powers.

  Fixpoint all0 (al: powers) : bool :=
   match al with
   | O :: al' => all0 al'
   | nil => true
   | _ => false
   end.

  Fixpoint cmp (al bl: powers) : comparison :=
  match al, bl with
  | al', nil => if all0 al' then Eq else Gt
  | nil, bl' => if all0 bl' then Eq else Lt
  | i :: al', j :: bl' => match Nat.compare i j with
                              | Lt => Lt | Gt => Gt 
                              | Eq => cmp al' bl'
                             end
  end.
   
  Definition lt al bl := cmp al bl = Lt.
  Definition eq al bl := cmp al bl = Eq.
  Lemma eq_refl: forall al, eq al al.
  Proof.
   unfold eq.
   induction al; simpl; auto.
   rewrite Nat.compare_refl; auto.
  Qed.

  Lemma eq_sym : forall al bl, eq al bl -> eq bl al.
  Proof.
    unfold eq.
    induction al; destruct bl; simpl; intros; auto.
    destruct n; try discriminate.
    destruct (all0 bl); try discriminate. auto.
    destruct a; try discriminate. destruct (all0 al); try discriminate; auto.
    rewrite Nat.compare_antisym. destruct (Nat.compare a n); try discriminate.
    simpl; auto.
  Qed.

 Lemma cmp_eq_all0:
  forall x y, cmp x y = Eq -> all0 x = true -> all0 y = true.
 Proof.
  induction x; destruct y; simpl; intros; auto.
  destruct n; simpl; auto. destruct (all0 y); intuition; congruence.
  discriminate.
  destruct (a ?= n) eqn:?H.
  apply Nat.compare_eq in H1. subst a.
  destruct n; auto. discriminate. discriminate.
 Qed.

Lemma all0_all0_cmp:
  forall x y, all0 x = true -> all0 y = true -> cmp x y = Eq.
 Proof.
  induction x; destruct y; simpl; intros; auto.
  destruct n; try discriminate.
  rewrite H0; auto.
  destruct a; try discriminate. rewrite H; auto.
  destruct n; try discriminate.
  destruct a; try discriminate.
  simpl; auto.
 Qed.


  Lemma eq_trans : forall x y z, eq x y -> eq y z -> eq x z.
  Proof.
    unfold eq.
    induction x; destruct y,z; intros; simpl in *; auto.
    destruct n; try discriminate.
    destruct (Nat.compare 0 n0) eqn:?H; try discriminate.
    destruct (all0 y) eqn:?H; try discriminate.
    apply Nat.compare_eq in H1. subst.
    rewrite (cmp_eq_all0 _ _ H0 H2). auto. 
    destruct a; try discriminate. destruct n; try discriminate.
    simpl. destruct (all0 x) eqn:?H; try discriminate.
     destruct (all0 z) eqn:?H; try discriminate.
    eapply all0_all0_cmp; eauto.
    destruct n; try discriminate.
    destruct (all0 y) eqn:?H; try discriminate.
    destruct (Nat.compare a 0) eqn:?H; try discriminate.
    apply Nat.compare_eq in H2. subst.
    apply eq_sym in H.
    rewrite (cmp_eq_all0 _ _ H H1). auto.
    destruct (Nat.compare n n0) eqn:?H; try discriminate.
    apply Nat.compare_eq in H1. subst.
    destruct (Nat.compare a n0) eqn:?H; try discriminate.
    eauto.
 Qed.

  Lemma all0_all0_lt:
   forall x y, cmp x y = Lt -> all0 x = false -> all0 y = false.
  Proof.
   induction x; destruct y; simpl; auto.
   destruct n; auto. destruct (all0 y); auto.
   destruct a; auto. destruct (all0 x); auto. congruence. congruence.
   intros.
   destruct a; try discriminate.
   destruct (Nat.compare 0 n) eqn:?H.
    apply Nat.compare_eq in H1. subst.
   eauto.
   destruct n; auto.
   rewrite Nat.compare_refl in H1. discriminate.
   destruct n; auto.
   rewrite Nat.compare_refl in H1. discriminate.
   destruct n; auto.
   simpl in H. discriminate.
 Qed.

  Lemma lt_trans: forall x y z : t, lt x y -> lt y z -> lt x z.
  Proof.
    unfold lt.
     induction x; destruct y,z; simpl; intros; auto.
    destruct n; try discriminate.
    destruct (all0 y) eqn:?H; try discriminate.
    destruct n; try discriminate.
    destruct (Nat.compare 0 n0) eqn:?H; try discriminate.
    apply Nat.compare_eq in H1. subst.
    destruct (all0 y) eqn:?H; try discriminate.
    rewrite (all0_all0_lt _ _ H0 H1). auto.
    destruct n0; auto.
    rewrite Nat.compare_refl in H1. discriminate.
    destruct n0; auto. simpl in H0. discriminate.
    destruct a; try discriminate.
    destruct (all0 x); try discriminate.
    destruct n; try discriminate.
    destruct (all0 y) eqn:?H; try discriminate.
    destruct (Nat.compare a n) eqn:?H; try discriminate.
    apply Nat.compare_eq in H1. subst.
    destruct (Nat.compare n n0) eqn:?H; try discriminate; auto.
    eauto.
    destruct (Nat.compare n n0) eqn:?H; try discriminate.
    apply Nat.compare_eq in H2. subst.
    rewrite H1. auto.
    apply Nat.compare_lt_iff in H1,H2.
    rewrite (proj2 (Nat.compare_lt_iff a n0)); auto.
    lia.
 Qed.

  Lemma lt_not_eq : forall x y : t, lt x y -> ~ eq x y.
  Proof.
   unfold lt, eq. intros; congruence.
  Qed.

Lemma cmp_antisym1: forall x y, cmp x y = Gt -> cmp y x = Lt.
Proof.
  induction x; destruct y; simpl; intros; auto.
      discriminate.
      destruct n; try discriminate.
      destruct (all0 y); discriminate.
      destruct a; try discriminate; auto.
      destruct (all0 x); auto; discriminate.
      rewrite Nat.compare_antisym. destruct (Nat.compare a n); try discriminate;
       simpl; auto.
  Qed.
 
  Definition compare ( x y : t) : OrderedType.Compare lt eq x y :=
match cmp x y as c0 return (cmp x y = c0 -> OrderedType.Compare lt eq x y) with
| Eq => fun H0 : cmp x y = Eq => OrderedType.EQ H0
| Lt => fun H0 : cmp x y = Lt => OrderedType.LT H0
| Gt => fun H0 : cmp x y = Gt => OrderedType.GT (cmp_antisym1 x y H0)
end (Logic.eq_refl _).

  Lemma eq_dec: forall x y, { eq x y } + { ~ eq x y }.
  Proof.
    unfold eq.
    intros.
    destruct (cmp x y).
    left; auto. right; congruence. right; congruence.
  Qed.

 End Keys.

Require FMapAVL.

Module Table := FMapAVL.Make Keys.

Definition intable_t := list coefficient.

(*
Definition normterm_to_intable (nt: normterm) :=
 (nt_coeff nt, nt_exp nt).
*)

Definition reflect_intable1_simple (k: Table.key) (it: coefficient) : expr :=
    reflect_normterm_simple (k,it).

Definition reflect_intable_simple (k: Table.key) (it: intable_t) (e: expr) : expr :=
 fold_right (Ebinary Add) e (map (reflect_intable1_simple k) it).

Lemma reflect_intable_cons:
  forall k a it e,
  reflect_intable_simple k (a::it) e ==
  Ebinary Add (reflect_intable1_simple k a) (reflect_intable_simple k it e).
Proof.
intros. intro.
destruct a as [aq ae].
unfold reflect_intable_simple.
match goal with |- context [map ?ff] => set (f:=ff) end.
unfold map; fold (map f).
unfold fold_right.
unfold eval; fold eval.
f_equal.
Qed.

Definition reflect_table (tab: Table.t intable_t) : expr :=
 Table.fold reflect_intable_simple tab zeroexpr.

Fixpoint cancel1_intable (yl: intable_t) (x: (QArith_base.Q * Z)): intable_t :=
 let '({|QArith_base.Qnum:= xn; QArith_base.Qden:= xd|}, xe) := x in
 match yl with
 | y::yl' =>
   let '({|QArith_base.Qnum:= yn; QArith_base.Qden:= yd|}, ye)  := y in
   if Z.eqb (Z.opp xn) yn && Pos.eqb xd yd && Z.eqb xe ye 
   then yl'
   else y :: cancel1_intable yl' x
 | nil => x::nil
 end.

Lemma cancel1_intable_correct:
  forall k yl x e, 
   reflect_intable_simple k (cancel1_intable yl x) e ==
   reflect_intable_simple k (x::yl) e.
Proof.
intros.
induction yl.
-
unfold cancel1_intable.
intro. f_equal. f_equal. destruct x,q; simpl; auto.
-

intro.
rewrite reflect_intable_cons.
unfold eval at 2; fold eval.
unfold binary_real.
rewrite reflect_intable_cons.
unfold eval at 3; fold eval.
unfold reflect_intable_simple.
simpl cancel1_intable.
destruct x as [[xn xd] xe].
destruct a as [[an ad] ae].
destruct ((-xn =? an)%Z && (xd =? ad)%positive && (xe =? ae)%Z) eqn:?H.
+
destruct (Z.eqb_spec (- xn) an); try discriminate.
destruct (Pos.eqb_spec xd ad); try discriminate.
destruct (Z.eqb_spec xe ae); try discriminate.
subst. clear H.
clear IHyl.
subst.
cbv [andb].
set (u := eval (fold_right _ _ _) _). clearbody u.
simpl.
destruct (Z.eqb_spec xn 0); [subst; simpl; lra | ].
destruct (Z.eqb_spec (-xn) 0); try lia. clear n0.
destruct (Z.eqb_spec xn 1); destruct (Z.eqb_spec (-xn) 1); try lia;
subst; clear; rewrite opp_IZR; ring.
+
clear H.
unfold reflect_intable_simple in IHyl.
match goal with |- context [map ?ff] => set (f:=ff) in * end.
unfold map; fold (map f).
change (fold_right (Ebinary Add) e (?a :: ?b))
  with (Ebinary Add a (fold_right (Ebinary Add) e b)).
specialize (IHyl env).
unfold eval at 1; fold eval. unfold binary_real.
rewrite IHyl; clear IHyl.
unfold map; fold (map f).
change (fold_right (Ebinary Add) e (?a :: ?b))
  with (Ebinary Add a (fold_right (Ebinary Add) e b)).
unfold eval; fold eval.
unfold binary_real.
set (u := eval (fold_right _ _ _) _); clearbody u.
change (f ?a) with (reflect_intable1_simple k a).
lra.
Qed.

Definition cancel_intable (it: intable_t) : intable_t :=
 fold_left cancel1_intable it nil.

Definition find_default [elt] (default: elt) (k: Table.key) (tab: Table.t elt) : elt :=
 match Table.find k tab with Some x => x | None => default end.

Definition add_to_table (tab: Table.t intable_t) (nt: normterm) :=
  let '(key,it) := nt in 
   Table.add key (cancel1_intable (find_default nil key tab) it) tab.

Lemma reflect_all0: forall j, Keys.all0 j = true -> forall n e, reflect_powers j n e == e.
Proof.
induction j; simpl; intros; intro; auto.
destruct a; try discriminate.
simpl. apply IHj; auto.
Qed.

Lemma Keys_cmp_eq:
  forall i j, Keys.eq i j -> forall n e, reflect_powers i n e == reflect_powers j n e.
Proof.
induction i; destruct  j; intros; intro; simpl in H; try discriminate; auto.
red in H; simpl in H. destruct n; try discriminate.
simpl.
destruct (Keys.all0 j) eqn:?H; try discriminate.
rewrite reflect_all0; auto.
hnf in H; simpl in H. destruct a; try discriminate.
destruct (Keys.all0 i) eqn:?H; try discriminate.
rewrite reflect_all0; auto.
simpl.
red in H; simpl in H.
destruct (Nat.compare_spec a n); try discriminate.
subst.
rewrite ?(reflect_power_untangle _ _ (reflect_powers _ _ _)).
simpl.
f_equal.
apply IHi. auto.
Qed.

Lemma fold_symmetric_setoid:
  forall [A : Type] [eqv: A -> A -> Prop] 
  (eqv_rel: Equivalence eqv)
  (f : A -> A -> A)
  (f_mor: forall x1 y1, eqv x1 y1 ->
              forall x2 y2, eqv x2 y2 ->
              eqv (f x1 x2) (f y1 y2)),
  (forall x y z : A, eqv (f x (f y z)) (f (f x y) z)) ->
  forall a0 : A,
  (forall y : A, eqv (f a0 y) (f y a0)) ->
  forall l : list A, eqv (fold_left f l a0) (fold_right f a0 l).
Proof.
intros.
induction l as [ | a1 l IHl]; [simpl; reflexivity | ].
simpl.
eapply  (@Equivalence_Transitive _ eqv eqv_rel).
2: apply f_mor; [reflexivity | apply IHl].
clear IHl. revert a1.
induction l as [|? ? IHl]; [ auto | ].
    simpl. intro.
apply  (@Equivalence_Transitive _ eqv eqv_rel)
 with (fold_left f l (f a0 (f a1 a))).
clear IHl.
assert (forall l b c, eqv b c -> eqv (fold_left f l b) (fold_left f l c)). {
  clear l a1 a a0 H0;
  induction l; simpl; intros; auto. apply IHl; apply f_mor; auto; reflexivity.
}
 apply H1; clear H1. symmetry. auto.
eapply  (@Equivalence_Transitive _ eqv eqv_rel).
apply IHl.
eapply  (@Equivalence_Transitive _ eqv eqv_rel).
2: apply f_mor; [ reflexivity | symmetry; apply IHl].
symmetry.
auto.
Qed.

Lemma fold_right_Add0_untangle:
  forall a l, fold_right Add0 a l == Add0 (fold_right Add0 zeroexpr l) a.
Proof.
intros.
revert a; induction l; simpl; intros; try reflexivity.
rewrite IHl.
rewrite !Add0_correct.
intro; simpl; ring.
Qed.

Lemma fold_right_Add0_Add:
  forall a l, fold_right Add0 a l == 
                fold_right (Ebinary Add) a l.
Proof.
intros.
induction l; simpl; intros; try reflexivity.
rewrite IHl.
rewrite Add0_correct.
reflexivity.
Qed.

Lemma fold_symmetric_Add0':
  forall l, fold_left Add0 l zeroexpr == fold_right Add0 zeroexpr l.
Proof.
intros.
apply fold_symmetric_setoid.
apply expr_equiv_rel.
intros. 
apply Add0_mor; auto.
intros. rewrite ?Add0_correct. intro; simpl; ring.
intros. rewrite ?Add0_correct. intro; simpl; ring.
Qed.

Lemma fold_symmetric_Add0:
  forall a l, fold_left Add0 l a == fold_right Add0 a l.
Proof.
intros.
rewrite fold_right_Add0_untangle.
rewrite <- fold_symmetric_Add0'.
set (b := zeroexpr).
set (c := a) at 1.
assert (c == Add0 b a). subst c b; reflexivity.
clearbody b c.
revert b c H; induction l; simpl; intros.
rewrite H.
rewrite !Add0_correct; intro; simpl;ring.
rewrite <- IHl.
2: reflexivity.
assert (Add0 c a0 == Add0 (Add0 b a0) a).
rewrite H. rewrite !Add0_correct; intro; simpl; ring.
set (d := Add0 c a0) in *.
set (e := Add0 (Add0 b a0) a) in *.
clearbody d; clearbody e; clear - H0.
revert d e H0; induction l; simpl; intros; auto.
apply IHl; auto.
rewrite H0; reflexivity.
Qed.

(*
Definition relate_fold_add:
 forall [elt A: Type]
     [eqv: A -> A -> Prop] 
     (eqv_rel: Equivalence eqv)
     (lift: Table.key -> elt -> A)
    (f:  A -> A -> A)
    (f_mor: forall x1 y1, eqv x1 y1 ->
              forall x2 y2, eqv x2 y2 ->
              eqv (f x1 x2) (f y1 y2))
  (f_assoc: forall x y z : A, eqv (f x (f y z)) (f (f x y) z))
  (f_commut: forall x y : A, eqv (f x y) (f y x))
  (u: elt)
  (f_unit: forall (k: Table.key) (y : A), eqv (f (lift k u) y) (f y (lift k u)))
  (tab: Table.t elt)
  (k: Table.key)
  eqv (Table.fold f (Table.add k ( find_default u k tab)) tab) u)
    (f 
Table.fold f tab u 

Definition relate_fold_add:
 forall [elt A: Type]
     [eqv: A -> A -> Prop] 
     (eqv_rel: Equivalence eqv)
    (f: Table.key -> elt -> A -> A)
    (f_mor: forall x1 y1, eqv x1 y1 ->
              forall x2 y2, eqv x2 y2 ->
              eqv (f x1 x2) (f y1 y2))
  (f_assoc: forall x y z : A, eqv (f x (f y z)) (f (f x y) z))
  (f_commut: forall x y : A, eqv (f x y) (f y x))
  (u: A)
  (f_unit: forall y : A, eqv (f u y) (f y u))
  (default: elt)
  (transform: Table.key * elt -> Table.key * elt)
  (tab: Table.t elt)
  (k: Table.key)
  eqv (Table.fold f (uncurry Table.add (transform (k, find_default default k tab)) tab) u)
    (f 
Table.fold f tab u 
*)

Definition add_to_table_simple (tab: Table.t intable_t) nt :=
Table.add (fst nt) (snd nt :: find_default [] (fst nt) tab) tab.

Lemma fold_bal:
  forall [elt A] (f: Table.Raw.key -> elt -> A -> A) (t1 t2: Table.Raw.tree elt) k e x,
  Table.Raw.fold f (Table.Raw.bal t1 k e t2) x = 
   Table.Raw.fold f t2 (f k e (Table.Raw.fold f t1 x)).
Proof.
intros.
unfold Table.Raw.bal.
repeat match goal with
 | |- context [if ?A then _ else _] => destruct A 
 | |- context [match Table.Raw.add ?p ?x ?y with _ => _ end] => 
                   destruct (Table.Raw.add p x y) eqn:?H
 | |- context [match ?t with _ => _ end ] => is_var t; destruct t 
end;
simpl; auto.
Qed.

Add Parametric Morphism : reflect_intable_simple
  with signature Keys.eq ==> eq ==> expr_equiv ==> expr_equiv
  as reflect_intable_simple_mor.
Proof.
intros k1 k2 ? t x1 x2 ?.
unfold reflect_intable_simple.
rewrite <- !fold_right_Add0_Add.
rewrite (fold_right_Add0_untangle x1).
rewrite (fold_right_Add0_untangle x2).
rewrite H0.
apply Add0_mor; try reflexivity.
clear H0 x1 x2.
rewrite !fold_right_Add0_Add.
induction t; simpl; auto.
reflexivity.
apply Ebinary_mor; auto.
unfold reflect_intable1_simple.
unfold reflect_normterm_simple.
apply Ebinary_mor; auto.
apply (Keys_cmp_eq k1 k2 H).
reflexivity.
Qed.

Definition fold_reflect_intable_simple := Table.Raw.fold reflect_intable_simple.

Add Parametric Morphism : fold_reflect_intable_simple
  with signature eq ==> expr_equiv ==> expr_equiv
  as fold_reflect_intable_simple_mor.
Proof.
intro t.
induction t; simpl; intros; auto.
apply IHt2.
apply reflect_intable_simple_mor; auto.
apply Keys.eq_refl.
Qed.

Lemma reflect_intable_simple_untangle:
  forall k t e, reflect_intable_simple k t e ==
         Ebinary Add (reflect_intable_simple k t zeroexpr) e.
Proof.
unfold reflect_intable_simple;
induction t; simpl; intro.
intro; simpl; ring.
rewrite IHt.
intro; simpl; ring.
Qed.

Lemma fold_reflect_intable_simple_untangle:
  forall t e, fold_reflect_intable_simple t e == 
   Ebinary Add (fold_reflect_intable_simple t zeroexpr) e.
Proof.
unfold fold_reflect_intable_simple.
induction t; intros; simpl.
intro; simpl; ring.
rewrite !(IHt2 (reflect_intable_simple _ _ _)).
rewrite (IHt1 e0).
rewrite reflect_intable_simple_untangle.
rewrite (reflect_intable_simple_untangle _ _ (Table.Raw.fold _ _ _)).
intro; simpl; ring.
Qed.

Lemma add_to_table_spec:
 forall tab nt,
  reflect_table (add_to_table tab nt) == reflect_table (add_to_table_simple tab nt).
Proof.
intros.
unfold add_to_table.
unfold add_to_table_simple.
destruct nt.
simpl.
unfold reflect_table.
set (j := find_default nil p tab).
clearbody j.
assert (H8 :=cancel1_intable_correct p j c).
set (new := cancel1_intable j c) in *; clearbody new.
fold coefficient in *.
set (old := c::j) in *; clearbody old.
destruct tab; unfold Table.fold, Table.add; simpl.
induction this.
simpl; auto.
inversion is_bst; clear is_bst; subst.
simpl.
destruct (Keys.compare p k).
-
rewrite !fold_bal.
apply fold_reflect_intable_simple_mor; auto.
apply reflect_intable_simple_mor; auto.
apply Keys.eq_refl.
-
simpl.
apply fold_reflect_intable_simple_mor; auto.
rewrite <- e0.
auto.
-
rewrite !fold_bal.
apply IHthis2 in H5.
set (u := Table.Raw.add p new this2) in *.
set (v := Table.Raw.add p old this2) in *.
clearbody u; clearbody v.
clear - H5.
fold intable_t.
fold (fold_reflect_intable_simple u) in *.
fold (fold_reflect_intable_simple v) in *.
rewrite !(fold_reflect_intable_simple_untangle _ (reflect_intable_simple _ _ _)).
rewrite H5.
reflexivity.
Qed.

Definition add_to_table_correct:
  forall tab nt, reflect_table (add_to_table tab nt) == 
            Ebinary Add (reflect_table tab) (reflect_normterm nt).
Proof.
intros.
rewrite add_to_table_spec.
unfold add_to_table_simple.
destruct nt as [key it].
unfold reflect_table.
simpl.
unfold find_default in *.
destruct tab; unfold Table.find, Table.fold, Table.add in *.
simpl in *.
fold intable_t in *.
destruct (Table.Raw.find key this) eqn:?H.
-
revert H; induction this; simpl; intros.
discriminate.
inversion is_bst; clear is_bst; subst.
destruct (Keys.compare key k).
+
apply IHthis1 in H; auto.
clear IHthis1 IHthis2.
rewrite fold_bal.
rewrite H; clear H.
fold fold_reflect_intable_simple.
rewrite !(fold_reflect_intable_simple_untangle _ (reflect_intable_simple _ _ _)).
rewrite reflect_intable_simple_untangle.
rewrite (reflect_intable_simple_untangle _ _ (Table.Raw.fold _ _ _)).
intro; simpl; ring.
+
inversion H; clear H; subst.
clear - e0.
rewrite (Keys_cmp_eq _ _ e0). clear key e0.
simpl.
set (u := Table.Raw.fold _ this1 _); clearbody u.
fold fold_reflect_intable_simple.
rewrite !(fold_reflect_intable_simple_untangle _ (reflect_intable_simple _ _ _)).
unfold reflect_intable_simple.
simpl.
rewrite reflect_powers_untangle.
unfold reflect_intable1_simple at 1.
unfold reflect_normterm_simple.
rewrite reflect_coeff_spec.
intro; simpl; ring.
+
apply IHthis2 in H; auto.
clear IHthis1 IHthis2.
rewrite fold_bal.
fold fold_reflect_intable_simple.
fold fold_reflect_intable_simple.
rewrite !(fold_reflect_intable_simple_untangle _ (reflect_intable_simple _ _ _)).
rewrite H.
clear.
fold fold_reflect_intable_simple.
intro; simpl; ring.
-
revert H; induction this; simpl; intros.
+
unfold reflect_intable_simple; simpl.
unfold reflect_intable1_simple.
simpl.
rewrite (reflect_powers_untangle _ _ (reflect_coeff it)).
rewrite reflect_coeff_spec.
intro; simpl; ring.
+
inversion is_bst; clear is_bst; subst.
destruct (Keys.compare key k); try discriminate.
* apply IHthis1 in H; auto; clear IHthis1 IHthis2.
 rewrite fold_bal.
 fold fold_reflect_intable_simple in *.
 rewrite H; clear.
 fold fold_reflect_intable_simple.
 set (u := fold_reflect_intable_simple this1 _); clearbody u.
 rewrite (reflect_intable_simple_untangle).
 rewrite (fold_reflect_intable_simple_untangle _ (Ebinary _ _ _)).
 rewrite (fold_reflect_intable_simple_untangle _ (reflect_intable_simple _ _ _)).
 rewrite (reflect_intable_simple_untangle _ _ u).
 intro; simpl; ring. 
* apply IHthis2 in H; auto; clear IHthis1 IHthis2.
 rewrite fold_bal.
 fold fold_reflect_intable_simple in *.
 set (u := Table.Raw.fold  _ this1 _); clearbody u.
 rewrite fold_reflect_intable_simple_untangle, H.
 clear.
 rewrite (fold_reflect_intable_simple_untangle _ (reflect_intable_simple _ _ _)).
 intro; simpl; ring.
Qed.

Definition reflect_intable_aux (al: intable_t) : expr :=
  fold_left Add0 (map reflect_coeff al) zeroexpr.

Definition reflect_intable (x: Table.key * intable_t) :=
 let '(p, it) := x in
 match reflect_intable_aux it with 
 | Econst (Int 0) => Econst (Int 0)
 | c => reflect_powers p 0 c
 end.

Definition sort_using_table (nts: list normterm) : expr -> expr :=
  fold_left (fun e it => Add0 (reflect_intable it) e)
  (Table.elements
    (fold_left add_to_table nts (Table.empty intable_t))).

Definition reflect_list l := fold_right Add0 zeroexpr (map reflect_intable l).

Definition sort_using_table_alt (nts: list normterm) (e0: expr) : expr :=
 Ebinary Add e0 
 (reflect_list
  (Table.elements
    (fold_right (Basics.flip add_to_table) (Table.empty intable_t) nts))).

Ltac reflect_powers_untangle := 
 repeat match goal with |- context [reflect_powers ?k ?i ?e] =>
  lazymatch e with zeroexpr => fail | _ => idtac end;
 rewrite (reflect_powers_untangle k i e)
end.

Lemma reflect_intable_simple_eqv:
 forall k i f, reflect_intable_simple k i f == Add0 (reflect_intable(k,i)) f.
Proof.
intros.
unfold reflect_intable.
unfold reflect_intable_aux.
pose proof (fold_symmetric_Add0 zeroexpr (map reflect_coeff i)).
set (a := fold_left _ _ _) in *. clearbody a.
destruct (Prog.expr_eq_dec a (Econst (Int 0))).
-
 subst. simpl.
 unfold reflect_intable_simple.
 transitivity (Ebinary Add (fold_right (Ebinary Add) zeroexpr (map (reflect_intable1_simple k) i)) f).
 clear; induction i; simpl; intros. intro; simpl; ring.
 rewrite IHi. intro; simpl; ring.
 transitivity (Ebinary Add zeroexpr f); [ | intro; simpl; ring].
 apply Ebinary_mor; auto; try reflexivity.
 transitivity (Ebinary Mul (reflect_powers k O oneexpr) 
            (fold_right Add0 zeroexpr (map reflect_coeff i))).
 2:{ rewrite <- H. intro; simpl; ring. }
 clear H.
 induction i; simpl. intro; simpl; ring.
 rewrite IHi. clear IHi.
 intro; simpl.
 rewrite Add0_correct; simpl.
 rewrite reflect_coeff_spec. ring.
-
transitivity (Add0 (reflect_powers k 0 a) f).
  2:{ destruct a as [ | [ [ | | ] | | ] | | ] ; try reflexivity. congruence. }
unfold reflect_intable_simple.
rewrite Add0_correct.
clear n.
rewrite H; clear H.
clear a.
transitivity (Ebinary Add (fold_right (Ebinary Add) zeroexpr (map (reflect_intable1_simple k) i)) f).
revert f; induction i; simpl; intros. intro; simpl; ring. rewrite IHi; intro; simpl; ring.
apply Ebinary_mor; auto; try reflexivity.
clear f.
induction i as [| [[n d] c] i].
+
rewrite reflect_powers_untangle. intro; simpl; ring.
+
unfold map; fold (map (reflect_intable1_simple k));  fold (map reflect_coeff).
unfold fold_right; 
 fold (fold_right (Ebinary Add) zeroexpr); fold (fold_right Add0 zeroexpr).
rewrite reflect_powers_untangle.
rewrite IHi; clear IHi.
rewrite reflect_coeff_spec.
set (u := fold_right Add0 _ _).
clearbody u.
rewrite reflect_powers_untangle.
rewrite Add0_correct.
intro; simpl.
set (p := reflect_powers _ _ _). clearbody p.
ring.
Qed.

Lemma reflect_list_rev: forall l, reflect_list (rev l) == reflect_list l.
Proof.
intros.
rewrite rev_alt.
set (c := @nil (Table.key * intable_t)).
intro.
transitivity (eval (reflect_list l) env + eval (reflect_list c) env); [ | simpl; lra].
clearbody c.
revert c; induction l; intros; simpl; auto.
lra.
unfold reflect_list at 2.
simpl.
rewrite IHl; clear IHl.
rewrite Add0_correct; simpl.
unfold reflect_list at 2.
simpl fold_right. rewrite Add0_correct; simpl.
fold (reflect_list l).
fold (reflect_list c). lra.
Qed.

Lemma reflect_elements: forall ta tb, reflect_table ta == reflect_table tb -> 
  reflect_list (Table.elements ta) == reflect_list (Table.elements tb).
Proof.
intros. intro. specialize (H env).
 unfold reflect_table in H.
 rewrite !Table.fold_1 in H.
 unfold reflect_list. simpl.
 set (al := Table.elements ta) in *.
 set (bl := Table.elements tb) in *.
 clearbody al bl.
 assert (forall al, 
   eval (fold_right Add0 zeroexpr (map reflect_intable al)) env =
   eval
     (fold_left
        (fun (a : expr) (p : Table.key * intable_t) =>
         reflect_intable_simple (fst p) (snd p) a) al zeroexpr) env);
   [ | rewrite !H0; auto].
 clear.
 intros.
 rewrite <- fold_left_rev_right, rev_alt.
 set (cl := @nil (Table.key * intable_t)) in *.
 transitivity
 (eval (fold_right Add0 zeroexpr (map reflect_intable cl)) env + 
  eval (fold_right Add0 zeroexpr (map reflect_intable al)) env).
 simpl; lra. 
 clearbody cl.
 revert cl; induction al; intros.
 2:{ simpl fold_right at 2. rewrite Add0_correct. simpl eval at 2.
   simpl rev_append. rewrite  <- IHal; clear IHal.
   simpl. rewrite Add0_correct. simpl; lra.
 }
 simpl eval at 2.  rewrite Rplus_0_r.
 simpl rev_append.
 induction cl; intros. simpl; auto.
 simpl eval at 1. rewrite Add0_correct. simpl eval at 1. rewrite IHcl; clear IHcl.
 set (f := fold_right _ _ _). simpl fold_right.
 change (fold_right _ _ _) with f.
 destruct a. clearbody f. unfold fst, snd.
 rewrite reflect_intable_simple_eqv. rewrite Add0_correct. reflexivity.
Qed.

Lemma reflect_table_elements:
  forall t, reflect_table t == reflect_list (Table.elements t).
Proof.
intros. intro.
unfold reflect_table.
rewrite Table.fold_1.
rewrite <- reflect_list_rev.
rewrite <- fold_left_rev_right.
unfold reflect_list.
induction (rev _); simpl; intros; auto.
destruct a.
rewrite Add0_correct. unfold eval; fold eval. unfold binary_real.
rewrite <- IHl.
unfold fst, snd.
rewrite reflect_intable_simple_eqv.
rewrite Add0_correct. unfold eval; fold eval. unfold binary_real.
auto.
Qed.

Lemma sort_using_table_eq: forall nts e,
 sort_using_table nts e == sort_using_table_alt nts e.
Proof.
unfold sort_using_table, sort_using_table_alt.
intros.
assert (reflect_table (fold_left add_to_table nts (Table.empty intable_t)) ==
          reflect_table (fold_right (Basics.flip add_to_table) (Table.empty intable_t) nts)). {
 intro.
 rewrite <- fold_left_rev_right.
 fold (Basics.flip add_to_table).
 rewrite rev_alt.
 set (nl := @nil normterm).
 set (t1 := Table.empty intable_t).
 replace t1 with (fold_right (Basics.flip add_to_table) t1 nl) at 2 by reflexivity.
 clearbody nl. clearbody t1.
 revert nl; induction nts; simpl; intros; auto.
 rewrite IHnts; clear IHnts.
 unfold fold_right at 2; fold (fold_right (Basics.flip add_to_table) t1).
 set (t2 := fold_right (Basics.flip add_to_table) t1 nl).
 unfold Basics.flip at 2 3.
 rewrite add_to_table_correct.
 unfold eval; fold eval. unfold binary_real.
 clearbody t2. clear.
 revert t2; induction nts; simpl; intros.
 rewrite add_to_table_correct. simpl; lra.
 unfold Basics.flip at 1 3.
 rewrite add_to_table_correct. simpl.
 rewrite IHnts; clear IHnts.
 set (t3 := fold_right _ _ _). clearbody t3.
 rewrite add_to_table_correct. simpl. lra.
}
match type of H with (reflect_table ?a == reflect_table ?b) =>
 set (ta := a) in *; set (tb := b) in *; clearbody ta; clearbody tb
end.
intro. specialize (H env).
simpl.
rewrite <- reflect_table_elements.
rewrite <- H; clear H.
rewrite <- fold_left_rev_right.
rewrite reflect_table_elements.
rewrite <- reflect_list_rev.
 set (cl := rev _).
 clearbody cl.
 revert e; induction cl; intros; simpl; [lra | ];
 rewrite Add0_correct; simpl; rewrite IHcl; clear IHcl;
 unfold reflect_list at 2; fold (reflect_list cl); simpl; rewrite Add0_correct; simpl; fold (reflect_list cl); lra.
Qed.

Lemma sort_using_table_correct:
 forall nts e, reflect_normterms nts e == sort_using_table nts e.
Proof.
intros. intro.
rewrite sort_using_table_eq.
unfold sort_using_table_alt.
revert e; induction nts; intros.
simpl. lra.
simpl eval at 1.
rewrite IHnts; clear IHnts.
simpl.
rewrite <- !reflect_table_elements.
unfold Basics.flip at 2.
rewrite add_to_table_correct.
simpl.
lra.
Qed.


Definition cancel_terms (e: expr) : expr :=
 let '(e1, nts) := normalize_terms false e nil in
         (sort_using_table nts e1).

Lemma cancel_terms_correct: forall e, cancel_terms e == e.
Proof.
intros.
unfold cancel_terms.
pose proof normalize_terms_correct false e nil.
destruct (normalize_terms false e []) as [e1 nts].
intro.  rewrite <- sort_using_table_correct.
rewrite H.
simpl. lra.
Qed.

Definition simplify_and_prune hyps e cutoff :=
    let e2 := ring_simp false 100 e in 
    let '(e1,slop) := prune (map b_hyps hyps) e2 cutoff in
    let e2 := ring_simp true 100 e1 in
    let e3 := cancel_terms e2 in
    (e3, slop).

Lemma prune_terms_correct2:
 forall hyps e cutoff e1 slop,  
   simplify_and_prune hyps e cutoff = (e1,slop) ->
  F.real slop = true ->
   forall vars r, 
     length hyps = length vars ->
     eval_hyps hyps vars (Rabs (eval e1 vars) <= r - F.toR slop) ->
      eval_hyps hyps vars (Rabs (eval e vars) <= r).
Proof.
intros.
unfold simplify_and_prune in H.
destruct (prune (map b_hyps hyps) (ring_simp false 100 e) cutoff) eqn:?H.
assert (t = slop) by congruence. subst t.
assert (e1 = cancel_terms (ring_simp true 100 e0)) by congruence. clear H; subst e1.
rewrite cancel_terms_correct in H2.
rewrite <- ring_simp_correct in H2.
eapply prune_terms_correct in H3; try eassumption; auto.
rewrite <- ring_simp_correct in H3.
auto.
Qed.

Ltac prune_terms cutoff := 
 simple_reify;
 match goal with |- eval_hyps _ _ (Rabs (eval ?e _) <= _) => 
    eapply (prune_terms_correct2 _ _ cutoff);  [vm_compute; reflexivity | reflexivity |  reflexivity |  try clear e]
 end;
 unfold_eval_hyps.


Definition simplify_and_prune_a hyps e cutoff :=
    let e2 := ring_simp false 100 e in 
    let '(e1,slop) := prune (map b_hyps hyps) e2 cutoff in
(*    let e2 := ring_simp true 100 e1 in*)
(*    let e3 := cancel_terms e2 in*)
    (e1, slop).


Lemma prune_terms_correct2a:
 forall hyps e cutoff e1 slop,  
   simplify_and_prune_a hyps e cutoff = (e1,slop) ->
  F.real slop = true ->
   forall vars r, 
     length hyps = length vars ->
     eval_hyps hyps vars (Rabs (eval e1 vars) <= r - F.toR slop) ->
      eval_hyps hyps vars (Rabs (eval e vars) <= r).
Abort.  (* easily proved, but needed only for measurement *)

Lemma prune_terms_correct2b:
 forall hyps e cutoff e1 slop,  
   simplify_and_prune_a hyps e cutoff = (e1,slop) ->
  F.real slop = true ->
   forall vars r, 
     length hyps = length vars ->
     eval_hyps hyps vars (Rabs (eval e1 vars) <= r - F.toR slop) ->
      eval_hyps hyps vars (Rabs (eval e vars) <= r).
Abort.  (* easily proved, but needed only for measurement *)

Ltac prune_terms' H cutoff := 
 simple_reify;
 match goal with |- eval_hyps _ _ (Rabs (eval ?e _) <= _) => 
    eapply (H _ _ cutoff);  [vm_compute; reflexivity | reflexivity |  reflexivity |  try clear e]
 end;
 unfold_eval_hyps.


Definition cutoff40 := Tactic_float.Float.scale (Tactic_float.Float.fromZ 1) (-40)%Z.
Definition cutoff30 := Tactic_float.Float.scale (Tactic_float.Float.fromZ 1) (-30)%Z.



Lemma test1:
 forall 
 (x v e0 d e1 e2 d0 e3 : R)
 (BOUND : -2 <= v <= 2)
 (BOUND0 : -2 <= x <= 2)
 (E : Rabs e0 <= / 713623846352979940529142984724747568191373312)
 (E0 : Rabs d <= / 16777216)
 (E1 : Rabs e1 <= / 1427247692705959881058285969449495136382746624)
 (E2 : Rabs e2 <= / 713623846352979940529142984724747568191373312)
 (E3 : Rabs d0 <= / 16777216)
 (E4 : Rabs e3 <= / 1427247692705959881058285969449495136382746624),
Rabs
  (((x + (1 / 32 * v + e2)) * (1 + d) + e3 + (1 / 2048 * - x + e0)) *
   (1 + d0) + e1 - (x + 1 / 32 * v + 1 / 2 * (1 / 32 * (1 / 32)) * - x)) <=
  4644337115725829 / 18889465931478580854784 + powerRZ 2 (-33).
Proof.
intros.
prune_terms cutoff30.
(*match goal with |- Rabs ?a <= _ => field_simplify a end.*)
match goal with |- Rabs ?t <= ?r => interval_intro (Rabs t) as H99 end.
eapply Rle_trans; [ apply H99 | clear  ].
simpl; compute; lra.
Qed.

Lemma test3: forall
 (x v d1 d2 e0 e1 e3 : R)
 (BOUND : -2 <= v <= 2)
 (BOUND0 : 2 <= x <= 4)
 (E : Rabs d1 <= / 16777216) 
 (E0 : Rabs d2 <= / 16777216)
 (E1 : Rabs e0 <= / 713623846352979940529142984724747568191373312)
 (E2 : Rabs e1 <= / 1427247692705959881058285969449495136382746624)
 (E3 : Rabs e3 <= / 713623846352979940529142984724747568191373312),
Rabs
  (((x + (1 / 32 * v + e0)) * (1 + d2) + (1 / 2048 * (3 - x) + e3)) *
   (1 + d1) + e1 -
   (x + 1 / 32 * v + 1 / 2 * (1 / 32 * (1 / 32)) * (3 - x))) <=
/ 2000000.
Proof.
intros.
prune_terms cutoff30.
match goal with |- Rabs ?t <= ?r => interval_intro (Rabs t) as H99 end.
eapply Rle_trans; [ apply H99 | clear  ].
simpl; compute; lra.
Qed.




Lemma test2:
 forall 
 (d d0 d1 e0 d2 e1 e2 e3 e4 e5 d3 e6 e7 e8 e9 e10 e11 e12 e13 d4 e14
e15 e16 e17 e18 d5 d6 d7 d8 e19 e20 d9 d10 d11 d12 e21 d13 e22 e23 e24
x v : R)
 (BOUND : (-2) <= v <= 2)
 (BOUND0 : (-2) <= x <= 2)
 (E : (Rabs d) <= (/ 16777216))
 ( E0 : (Rabs d0) <= (/ 16777216))
 ( E1 : (Rabs d1) <= (/ 16777216)) 
( E2 : (Rabs e0) <= (/ 1427247692705959881058285969449495136382746624))
 (E3 : (Rabs d2) <= (/ 16777216)) 
 (E4 : (Rabs e1) <= (/ 713623846352979940529142984724747568191373312))
 ( E5 : (Rabs e2) <= (/ 1427247692705959881058285969449495136382746624))
 ( E6 : (Rabs e3) <= (/ 1427247692705959881058285969449495136382746624))
 ( E7 : (Rabs e4) <= (/ 1427247692705959881058285969449495136382746624))
 ( E8 : (Rabs e5) <= (/ 1427247692705959881058285969449495136382746624)) 
( E9 : (Rabs d3) <= (/ 16777216))
 ( E10 : (Rabs e6) <= (/ 713623846352979940529142984724747568191373312)) 
( E11 : (Rabs e7) <= (/ 713623846352979940529142984724747568191373312))
 ( E12 : (Rabs e8) <= (/ 713623846352979940529142984724747568191373312))
 ( E13 : (Rabs e9) <= (/ 713623846352979940529142984724747568191373312)) 
 ( E14 : (Rabs e10) <= (/ 1427247692705959881058285969449495136382746624))
 ( E15 : (Rabs e11) <= (/ 1427247692705959881058285969449495136382746624)) 
( E16 : (Rabs e12) <= (/ 1427247692705959881058285969449495136382746624))
 ( E17 : (Rabs e13) <= (/ 1427247692705959881058285969449495136382746624))
 ( E18 : (Rabs d4) <= (/ 16777216))
 ( E19 : (Rabs e14) <= (/ 713623846352979940529142984724747568191373312))
 ( E20 : (Rabs e15) <= (/ 1427247692705959881058285969449495136382746624))
 (E21 : (Rabs e16) <= (/ 1427247692705959881058285969449495136382746624) )
( E22 : (Rabs e17) <= (/ 1427247692705959881058285969449495136382746624))
 ( E23 : (Rabs e18) <= (/ 1427247692705959881058285969449495136382746624)) 
( E24 : (Rabs d5) <= (/ 16777216))
(E25 : (Rabs d6) <= (/ 16777216))
(E26 : (Rabs d7) <= (/ 16777216))
(E27 : (Rabs d8) <= (/ 16777216))
(E28 : (Rabs e19) <= (/ 713623846352979940529142984724747568191373312))
(E29 : (Rabs e20) <= (/ 1427247692705959881058285969449495136382746624))
(E30 : (Rabs d9) <= (/ 16777216))
(E31 : (Rabs d10) <= (/ 16777216))
(E32 : (Rabs d11) <= (/ 16777216))
(E33 : (Rabs d12) <= (/ 16777216))
(E34 : (Rabs e21) <= (/ 713623846352979940529142984724747568191373312))
(E35 : (Rabs d13) <= (/ 16777216))
(E36 : (Rabs e22) <= (/ 713623846352979940529142984724747568191373312))
(E37 : (Rabs e23) <= (/ 713623846352979940529142984724747568191373312))
(E38 : (Rabs e24) <= (/ 1427247692705959881058285969449495136382746624)),
  Rabs
    (((((x + (1 / 32 * v + e14)) * (1 + d3) + e20 + (1 / 2048 * - x + e1)) *
       (1 + d5) + e10) *
      (((x + (1 / 32 * v + e21)) * (1 + d1) + e17 + (1 / 2048 * - x + e8)) *
       (1 + d11) + e4) * (1 + d8) + e13 +
      (((v +
         (1 / 64 *
          ((- x +
            -
            (((x + (1 / 32 * v + e23)) * (1 + d0) + e16 +
              (1 / 2048 * - x + e7)) * (1 + d10) + e3)) * 
           (1 + d7) + e12) + e22)) * (1 + d2) + e18) *
       ((v +
         (1 / 64 *
          ((- x +
            -
            (((x + (1 / 32 * v + e9)) * (1 + d12) + e5 +
              (1 / 2048 * - x + e19)) * (1 + d4) + e24)) * 
           (1 + d) + e15) + e6)) * (1 + d9) + e2) * 
       (1 + d6) + e11)) * (1 + d13) + e0 -
     ((x + 1 / 32 * v + 1 / 2 * (1 / 32 * (1 / 32)) * - x) *
      (x + 1 / 32 * v + 1 / 2 * (1 / 32 * (1 / 32)) * - x) +
      (v +
       1 / 2 * (1 / 32) *
       (- x + - (x + 1 / 32 * v + 1 / 2 * (1 / 32 * (1 / 32)) * - x))) *
      (v +
       1 / 2 * (1 / 32) *
       (- x + - (x + 1 / 32 * v + 1 / 2 * (1 / 32 * (1 / 32)) * - x))))) <=
 5981343255101459 / 2361183241434822606848 + powerRZ 2 (-27).
Proof.
intros.
(*
simple_reify.
match goal with |- context [eval ?e] =>
 let e := constr:(ring_simp false 100 e) in 
 let e := constr:(fst (prune (map b_hyps __hyps) e cutoff30)) in
 let e := constr:(ring_simp true 100 e) in 
 let e := constr:(cancel_terms e) in
 let u := constr:((count_nodes e, count_terms e)) in let u := eval vm_compute in u in
 assert (fst u >=0)%Z; clear
 end.
*)
(* 242 nodes in original expression *)
(* 612284 nodes, 31759 terms after ring_simp false 100 e *)
(* 389520 nodes, 4550 terms after ring_simp true 100 e *)
(* 1456 nodes, 244 terms after prune with cutoff30 *)
(* 1060 nodes, 112 terms  after ring_simp true 100 e *)
(* 289 nodes, 25 terms after cancel_terms e *)

Time prune_terms cutoff30.  (* 1.871 sec *)
(*Time match goal with |- Rabs ?a <= _ => field_simplify a end.*)
match goal with |- Rabs ?t <= ?r => interval_intro (Rabs t) as H99 end;
eapply Rle_trans; [ apply H99 | clear  ].
simpl; compute; lra.
Qed.


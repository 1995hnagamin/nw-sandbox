#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include "9cc.h"

void get_lval(Node *node) {
  if (node->kind != ND_LVAR) {
    error("the lhs of assignment expression should be a variable");
  }
  printf("  mov rax, rbp\n");
  printf("  sub rax, %d      # get lval: offset %d\n", node->lvar->offset, node->lvar->offset);
  printf("  push rax\n");
}

int GENSYM_IDX;
int gensym() {
  return ++GENSYM_IDX;
}

int nbytes_type(Type *ty) {
  switch (ty->kind) {
  case TY_INT:
    return sizeof(int);
  case TY_PTR:
    return sizeof(int*);
  }
}

void gen_if_stmt(Node *node) {
  int end_label = gensym();
  gen(node->lhs);
  printf("  pop rax         # if statement\n");
  printf("  cmp rax, 0\n");
  if (node->rhs->rhs) {
    int else_label = gensym();
    printf("  je .L.else.%d\n", else_label);
    gen(node->rhs->lhs); // then
    printf("  jmp .L.end.%d\n", end_label);
    printf(".L.else.%d:\n", else_label);
    gen(node->rhs->rhs); // else
  } else {
    printf("  je .L.end.%d\n", end_label);
    gen(node->rhs->lhs); // then
  }
  printf(".L.end.%d:\n", end_label);
  return;
}

char *REG_NAMES[6] = {"rdi", "rsi", "rdx", "rcx", "r8", "r9"};

void gen_fn_def(Node *def) {
  printf("_%.*s:\n", def->tok->len, def->tok->str);
  printf("  push rbp\n");
  printf("  mov rbp, rsp\n");
  printf("  sub rsp, 208\n");
  int i = 0;
  for (Node *param = def->rhs; param; param = param->rhs) {
    printf("  mov rax, rbp\n");
    printf("  sub rax, %d\n", param->lhs->lvar->offset);
    printf("  mov [rax], %s\n", REG_NAMES[i++]);
  }
  gen(def->lhs); // function body
  printf("  mov rsp, rbp\n");
  printf("  pop rbp\n");
  printf("  ret\n");
}

void gen_fn_call(Node *call) {
  Node *arg = call->rhs;
  for (int i = 0; i < 6 && arg; ++i, arg = arg->rhs) {
    gen(arg->lhs);
    printf("  pop %s\n", REG_NAMES[i]);
  }
  // https://stackoverflow.com/a/9600102
  printf("  push rsp          # 16-align\n");
  printf("  push [rsp]\n");
  printf("  and rsp, -0x10\n");
  printf("  call _%.*s\n", call->tok->len, call->tok->str);
  printf("  mov rsp, [rsp + 8]\n");
  printf("  push rax\n");
}

void gen(Node *node) {
  switch (node->kind) {
  case ND_FNDEF:
    gen_fn_def(node);
    return;
  case ND_DECL:
    printf("  push 0          # dummy instruction\n");
    break;
  case ND_INT:
    printf("  push %d          # integer\n", node->val);
    return;
  case ND_LVAR:
    get_lval(node);
    printf("  pop rax         # pop address to rax \n");
    printf("  mov rax, [rax]\n");
    printf("  push rax\n");
    return;
  case ND_IF:
    gen_if_stmt(node);
    return;
  case ND_ASSIGN:
    printf("  # ND_ASSIGN\n");
    if (node->lhs->kind == ND_LVAR) {
      get_lval(node->lhs);
    } else {
      // node->lhs =  *p
      gen(node->lhs->lhs);
    }
    gen(node->rhs);
    printf("  pop rdi         # pop rhs to rdi\n");
    printf("  pop rax         # pop address to rax\n");
    printf("  mov [rax], rdi\n");
    printf("  push rdi\n");
    return;
  case ND_FNCALL:
    gen_fn_call(node);
    break;
  case ND_RETURN:
    gen(node->lhs);
    printf("  pop rax         # pop return value to rax\n");
    printf("  mov rsp, rbp\n");
    printf("  pop rbp\n");
    printf("  ret\n");
    return;
  case ND_BLOCK:
    for (Node *s = node->rhs; s; s = s->rhs) {
      gen(s->lhs);
      printf("  pop rax       # pop statement value to rax\n");
    }
    return;
  case ND_ADD:
    gen(node->lhs);
    gen(node->rhs);
    if (node->lhs->ty->kind == TY_PTR) {
      printf("  pop rdi         # pop rhs to rdi\n");
      printf("  imul rdi, %d\n", nbytes_type(node->lhs->ty->ptr_to));
      printf("  pop rax         # pop lhs to rax\n");
      printf("  add rax, rdi    # rax += rdi\n");
      printf("  push rax\n");
      break;
    } else if (node->rhs->ty->kind == TY_PTR) {
      printf("  pop rdi         # pop rhs to rdi\n");
      printf("  pop rax         # pop lhs to rax\n");
      printf("  imul rax, %d\n", nbytes_type(node->lhs->ty->ptr_to));
      printf("  add rax, rdi    # rax += rdi\n");
      printf("  push rax\n");
      break;
    }
    printf("  pop rdi         # pop rhs to rdi\n");
    printf("  pop rax         # pop lhs to rax\n");
    printf("  add rax, rdi    # rax += rdi\n");
    printf("  push rax\n");
    break;
  case ND_SUB:
    gen(node->lhs);
    gen(node->rhs);
    printf("  pop rdi         # pop rhs to rdi\n");
    printf("  pop rax         # pop lhs to rax\n");
    printf("  sub rax, rdi    # rax -= rdi\n");
    printf("  push rax\n");
    break;
  case ND_MUL:
    gen(node->lhs);
    gen(node->rhs);
    printf("  pop rdi         # pop rhs to rdi\n");
    printf("  pop rax         # pop lhs to rax\n");
    printf("  imul rax, rdi   # rax *= rdi\n");
    printf("  push rax\n");
    break;
  case ND_DIV:
    gen(node->lhs);
    gen(node->rhs);
    printf("  pop rdi         # pop rhs to rdi\n");
    printf("  pop rax         # pop lhs to rax\n");
    printf("  cqo\n");
    printf("  idiv rdi        # rax /= rdi\n");
    printf("  push rax\n");
    break;
  case ND_EQU:
    gen(node->lhs);
    gen(node->rhs);
    printf("  pop rdi         # pop rhs to rdi\n");
    printf("  pop rax         # pop lhs to rax\n");
    printf("  cmp rax, rdi    # [lhs = rhs]?\n");
    printf("  sete al\n");
    printf("  movzx rax, al\n");
    printf("  push rax\n");
    break;
  case ND_NEQ:
    gen(node->lhs);
    gen(node->rhs);
    printf("  pop rdi         # pop rhs to rdi\n");
    printf("  pop rax         # pop lhs to rax\n");
    printf("  cmp rax, rdi    # [lhs != rhs]?\n");
    printf("  setne al\n");
    printf("  movzx rax, al\n");
    printf("  push rax\n");
    break;
  case ND_LES:
    gen(node->lhs);
    gen(node->rhs);
    printf("  pop rdi         # pop rhs to rdi\n");
    printf("  pop rax         # pop lhs to rax\n");
    printf("  cmp rax, rdi    # [lhs < rhs]?\n");
    printf("  setl al\n");
    printf("  movzx rax, al\n");
    printf("  push rax\n");
    break;
  case ND_LEQ:
    gen(node->lhs);
    gen(node->rhs);
    printf("  pop rdi         # pop rhs to rdi\n");
    printf("  pop rax         # pop lhs to rax\n");
    printf("  cmp rax, rdi    # [lhs <= rhs]?\n");
    printf("  setle al\n");
    printf("  movzx rax, al\n");
    printf("  push rax\n");
    break;
  case ND_ADDR:
    get_lval(node->lhs);
    break;
  case ND_DEREF:
    gen(node->lhs);
    printf("  pop rax\n");
    printf("  mov rax, [rax]\n");
    printf("  push rax\n");
    break;
  case ND_INVALID:
    fprintf(stderr, "fatal error in gen()\n");
    exit(1);
  }
}

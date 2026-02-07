import * as express from "express";

declare global {
  namespace Express {
    interface Request {
      user: {
        uid?: string;
        firebase_id: string;
        email: string;
        role?: string;
      }
    }
  }
}
